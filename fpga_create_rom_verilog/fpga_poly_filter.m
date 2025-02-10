% Resampling filter for SPEC 0
%
b = 16;  % number of bits 

L = 375;
M = 256;
taps = 8;  % taps per polyphase branch

% total number of taps
N = taps*L;

bta = 5;
h = fir1(N-1, 1/L, kaiser(N, bta));

figure
[H,f] = freqz(h, 1, 1024, 'whole', 1);
plot(f, db(abs(H)) );
grid
title(['Resample filter, L = 375, M = 256, beta = ',num2str(bta)]);

%reshape for polyphase interpolator structure, put branches in order
%then collapse into one vector for RAM
% h = [h1,h2,h3,.....hL]
h = reshape(h, L, N/L);
h = resample(h', 1, N);

% convert to unsigned ints
hb = twos2int(h, b);

write_ram_coe('hb16_poly.coe', hb);
