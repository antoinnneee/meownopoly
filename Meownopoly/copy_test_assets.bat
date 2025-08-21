@echo off
echo Copying test assets...

copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\element\grass\0.png" "assets\decoration\grass\1.png"
copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\element\grass\1.png" "assets\decoration\grass\2.png"
copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\element\grass\2.png" "assets\decoration\grass\3.png"

copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\element\tree\0.png" "assets\decoration\tree\1.png"
copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\element\tree\1.png" "assets\decoration\tree\2.png"

copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\avatar\avatar1.png" "assets\player_icons\1.png"
copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\avatar\avatar2.png" "assets\player_icons\2.png"
copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\avatar\avatar3.png" "assets\player_icons\3.png"
copy "build\Desktop_Qt_6_9_1_MinGW_64_bit-Debug\asset_extracted\avatar\avatar4.png" "assets\player_icons\4.png"

echo Done copying test assets!
pause
