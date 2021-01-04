// Outputs the 4 bram files
// arr: string array of 32-bit hex
// sz : total size of ram (# of 32-bit words)
function encode(arr, sz) {
    let bram0 = '';
    let bram1 = '';
    let bram2 = '';
    let bram3 = '';
    for(let i = 0; i < sz; i++) {
        let sp = ' ';
        if((i+1) % 16 == 0) {
            if(i+1 < sz)
                sp = '\n';
            else
                sp = '';
        }
        bram3 += (arr[i] ? arr[i].substring(0, 2).toUpperCase() : '00') + sp;
        bram2 += (arr[i] ? arr[i].substring(2, 4).toUpperCase() : '00') + sp;
        bram1 += (arr[i] ? arr[i].substring(4, 6).toUpperCase() : '00') + sp;
        bram0 += (arr[i] ? arr[i].substring(6, 8).toUpperCase() : '00') + sp;
    }
    fs = require('fs');
    fs.writeFile('bram0.hex', bram0, (e, d) => {});
    fs.writeFile('bram1.hex', bram1, (e, d) => {});
    fs.writeFile('bram2.hex', bram2, (e, d) => {});
    fs.writeFile('bram3.hex', bram3, (e, d) => {});
}

let blinky = [
    '2400FF00', // MOV r0 <- 0xFF00
    '24100000', // MOV r1 <- 0x0000
    '34100084', // STR [r0+0x84] <- r1
    '241001FF', // MOV r1 <- 0x01FF
    '34100080', // STR [r0+0x80] <- r1
    '2420FFFF', // MOV r2 <- 0xFFFF
    '64220001', // SUB r2 <- r2 - 1
    '6C220000', // CMP r2, 0
    '52FFFFF8', // B<0010> -8
    '24100001', // MOV r1 <- 0x0001
    '34100084', // STR [r0+0x84] <- r1
    '2420FFFF', // MOV r2 <- 0xFFFF
    '64220001', // SUB r2 <- r2 - 1
    '6C220000', // CMP r2, 0
    '52FFFFF8', // B<0010> -8
    '24F00000', // MOV PC, 0
];
encode(blinky, 256);
