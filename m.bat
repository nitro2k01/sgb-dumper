: Point rgbenv to a directory (including trailing backslash) containing preferably RGBDS 0.6.1, if not already in the path.
@set rgbenv=C:\Users\nitro2k01\gbdev\rgbds\
@set old_prompt=%prompt%
@set prompt=$
@mkdir obj 2>nul
@mkdir bin 2>nul
%rgbenv%rgbasm -oobj/util.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/util.asm
@if errorlevel 1 goto lbl_err
%rgbenv%rgbasm -oobj/sgb.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/sgb.asm
@if errorlevel 1 goto lbl_err
%rgbenv%rgbasm -oobj/sgbdumper.o -Wunmapped-char -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/sgbdumper.asm
@if errorlevel 1 goto lbl_err
%rgbenv%rgbasm -oobj/sgb_comm.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/sgb_comm.asm
@if errorlevel 1 goto lbl_err
%rgbenv%rgblink -t -w -p0xFF -o bin/sgbdumper.gb -m bin/sgbdumper.map -n bin/sgbdumper.sym obj/sgbdumper.o obj/sgb_comm.o obj/util.o obj/sgb.o 
@if errorlevel 1 goto lbl_err
%rgbenv%rgbfix -v -r4 -m0x1b -s -l 0x33 -n 1 -p0xFF -t "sgbdumper" bin/sgbdumper.gb
@if errorlevel 1 goto lbl_err
: Copy the build to an Analogue Pocket in USB mode, if connected.
copy /y bin\sgbdumper.gb d:\Assets\sgb\common\sgbdumper.gb
@goto lbl_end
:lbl_err
@echo Error!
:lbl_end
@set prompt=%old_prompt%
