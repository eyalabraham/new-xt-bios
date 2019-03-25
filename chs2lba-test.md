# Test code

**Test cylinder-head-sector conversion to LBA addressing**
```
 ;-----------------------------------------------------------------------
 ; test CHS2LBA
 ;                                               ;
 ; entry:                                        ;
 ;   CH track number                             ;
 ;   CL sector number & 2 high bits of track num ;
 ;   DH head number                              ;
 ;   DL drive                                    ;
 ; exit:                                         ;
 ;   AL low LBA byte b0..b7                      ;
 ;   AH mid LBA byte b8..b15                     ;
 ;   DL high LBA byte b16..b23                   ;
 ;   DH high LBA nible b24..b27                  ;
 ;   CY.f = 0 conversion ok                      ;
 ;   CY.f = 1 failed, CHS out of range           ;
 ;   all other work registers preserved          ;
 ;-----------------------------------------------;
 ;
                 mov         cl,1                        ; 1 to 18
                 mov         ch,0                        ; 0 to 79
                 mov         dl,0                        ; 0
                 mov         dh,0                        ; 0 to 1
 AGAIN:          push        dx
                 call        PRINTREGS
                 call        CHS2LBA
                 call        PRINTREGS
                 pop         dx
                 inc         cl
                 cmp         cl,19
                 jnz         AGAIN
                 mov         cl,1
                 inc         dh
                 cmp         dh,2
                 jnz         AGAIN
                 mov         dh,0
                 inc         ch
                 cmp         ch,80
                 jnz         AGAIN
 ;
 ;-----------------------------------------------------------------------
```

