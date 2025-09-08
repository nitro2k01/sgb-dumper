: Point to cc65's bin directory (including trailing backslash) if not already in the path.
@set cc65env=
@echo.
@echo.
%cc65env%ca65.exe src\snespayload.asm -o obj/snespayload.o
%cc65env%ld65.exe -o build/snespayload.bin -m build/map.txt -C snesram.cfg obj/snespayload.o
