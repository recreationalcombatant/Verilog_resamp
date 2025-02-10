% Resampling filter for SPEC 0
% Creates verilog .v files for each ROM table

% set to use clocked ROM or combinatorial ROM
use_clk = 0;

b = 16;  % number of bits for coeffs

L = 375;  % interp rate
M = 256;  % dec rate
taps = 5; % taps per polyphase branch

% total number of taps in filter
N = taps*L;

% filter gen - interpolator with L gain at DC
bta = 5;
h = L*fir1(N-1, 1/L, kaiser(N, bta));

figure
[H,f] = freqz(h, 1, 1024, 'whole', 1);
plot(f, db(abs(H)) );

%reshape for polyphase interpolator structure
h = reshape(h, L, N/L);

%%%%%%%%%%%%%%%
%h = zeros(L, N/L);
%h(:,1) = -ones(1,L);
%%%%%%%%%%%%%%%

% convert to unsigned ints
hb = twos2int(h, b);
hf = int2fix(hb, b);

[H,f] = freqz(hf, 1, 1024, 'whole', 1);
hold
plot(f, db(abs(H)), 'r' );
grid
title(['Resample filter, L = 375, M = 256, beta = ',num2str(bta)]);

addy_bits = nextpow2(L);

%----- now create ROM modules for verilog implementation ----
for i=1:taps
    fname = ['fir_rom',num2str(i),'.v'];
    fid = fopen(fname, 'w');
    disp(['Writing to: ',fname]);
    fprintf(fid, '`timescale 1ns / 1ps\n');
    fprintf(fid,'///////////////////////////////////////////\n');
    fprintf(fid,'// ROM table - 2''s complement coefficients\n');
    fprintf(fid, ['// ',fname,': FIR polyphase branch (',num2str(i),')\n']);
    fprintf(fid, '// \n');
    fprintf(fid, ['// Created: ', datestr(now),'\n']);
    fprintf(fid, '//  from Matlab script fpga_create_rom_verilog.m\n');
    fprintf(fid, '//\n');
    fprintf(fid, '// J. Shima\n');
    fprintf(fid, '//////////////////////////////////////////\n');
    if(use_clk)
       fprintf(fid, ['module fir_rom',num2str(i),'(CLK, ADDR, DATA);\n']);
       fprintf(fid, '    input CLK;\n');
    else
       fprintf(fid, ['module fir_rom',num2str(i),'(ADDR, DATA);\n']);
    end
    fprintf(fid, ['    input [',num2str(addy_bits-1),':0] ADDR;\n']);
    fprintf(fid, ['    output signed [',num2str(b-1),':0] DATA;\n']);
    fprintf(fid, ['    reg signed [',num2str(b-1),':0] DATA;\n']);
    fprintf(fid, '\n');   
    if(use_clk)
        fprintf(fid, '    always@(posedge CLK) begin\n');
    else
        fprintf(fid, '    always@(ADDR) begin\n');
    end
    fprintf(fid, '        case(ADDR)\n');

    for j=1:L
      fprintf(fid, ['          ',num2str(addy_bits),'''b',dec2bin(j-1,addy_bits),':  DATA = ',num2str(b),'''b',dec2bin(hb(j,i),b),';    // h',num2str(j),'_',num2str(i),'=(',num2str(hf(j,i)),')\n' ]);
    end

    fprintf(fid, ['          default : DATA = ',num2str(b),'''b',dec2bin(0,b),';\n' ]);
    fprintf(fid, '        endcase\n');
    fprintf(fid, '    end\n');
    fprintf(fid, 'endmodule\n');
    fprintf(fid, '\n');
    fclose(fid);
end


