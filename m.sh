mkdir -p obj
mkdir -p bin
rgbasm -oobj/util.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/util.asm &&
rgbasm -oobj/sgb.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/sgb.asm &&
rgbasm -oobj/sgb_gfx.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ -i./gfx_im/ src/sgb_gfx.asm &&
rgbasm -oobj/sgbdumper.o -Wunmapped-char -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/sgbdumper.asm &&
rgbasm -oobj/sgb_comm.o -Wno-obsolete -p 0xFF -isrc/ -ires/ -i./common/ src/sgb_comm.asm &&
rgblink -t -w -p0xFF -o bin/sgbdumper.gb -m bin/sgbdumper.map -n bin/sgbdumper.sym obj/sgbdumper.o obj/sgb_comm.o obj/util.o obj/sgb.o obj/sgb_gfx.o &&
rgbfix -v -r4 -m0x1b -s -l 0x33 -n 1 -p0xFF -t "sgbdumper" bin/sgbdumper.gb
