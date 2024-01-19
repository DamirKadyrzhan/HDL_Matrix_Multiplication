clc
A = randi([0 9], 32, 32);
B = randi([0 9], 32, 32);
C = randi([0 9], 32, 32);
D = A*B + C; 

AHex = dec2hex(A', 2);
BHex = dec2hex(B', 2);
CHex = dec2hex(C', 2);
DHex = dec2hex(D', 5);

fileID = fopen('InputA.txt', 'w');
for i = 1:size(AHex, 1)
    fprintf(fileID, '    ''%s''\n', AHex(i, :));
end
fclose(fileID);

fileID1 = fopen('InputB.txt', 'w');
for i = 1:size(BHex, 1)
    fprintf(fileID1, '    ''%s''\n', BHex(i, :));
end
fclose(fileID1);

fileID2 = fopen('InputC.txt', 'w');
for i = 1:size(CHex, 1)
    fprintf(fileID2, '    ''%s''\n', CHex(i, :));
end
fclose(fileID2);

fileID3 = fopen('OutputD_matlab.txt', 'w');
for i = 1:size(DHex, 1)
    fprintf(fileID3, '    ''%s''\n', DHex(i, :));
end
fclose(fileID3);
