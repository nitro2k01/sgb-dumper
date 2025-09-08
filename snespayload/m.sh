ca65 src/snespayload.asm -o obj/snespayload.o
ld65 -o build/snespayload.bin -m build/map.txt -C snesram.cfg obj/snespayload.o
