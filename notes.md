
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





