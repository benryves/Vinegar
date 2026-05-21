rmdir "TI-83" /s /q
rmdir "TI-83 Plus" /s /q
mkdir "TI-83"
mkdir "TI-83 Plus"
cd "TI-83"
mkdir "SCHIP"
mkdir "CHIP-8"
cd "..\TI-83 Plus"
mkdir "SCHIP"
mkdir "CHIP-8"
cd ..
for /r %%i in (*.c8) do "CHIP-8 Converter.exe" "%%i"
move *.83p "TI-83\CHIP-8\"
move *.8xp "TI-83 Plus\CHIP-8\"
for /r %%i in (*.sc) do "CHIP-8 Converter.exe" "%%i"
move *.83p "TI-83\SCHIP\"
move *.8xp "TI-83 Plus\SCHIP\"