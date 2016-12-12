
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
