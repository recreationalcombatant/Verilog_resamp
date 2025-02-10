% Resampling filter for SPEC 0

b = 16;  % number of bits for coeffs

x = int2fix(16000,b)*ones(1,1000);

L = 375;  % interp rate
M = 256;  % dec rate
taps = 5; % taps per polyphase branch

% total number of taps in filter
N = taps*L;

% filter gen
bta = 5;
h = L*fir1(N-1, 1/L, kaiser(N, bta));
hq = fxquant(h,b,'round','sat');

figure
[H,f] = freqz(h, 1, 1024, 'whole', 1);
plot(f, db(abs(H)) );
[H,f] = freqz(hq, 1, 1024, 'whole', 1);
hold
plot(f, db(abs(H)), 'r' );
grid
title(['Resample filter, L = 375, M = 256, beta = ',num2str(bta)]);

%reshape for polyphase interpolator structure
hf = reshape(hq, L, taps);

[r,c] = size(hf);
hist = zeros(1,taps);
hist(1) = x(1);
cnt = 1;
n = 2;

Lx = length(x);
Ntotal = floor( (Lx*L + N)/M);

% Do resampling.  We are going to do polyphase interpolation by L, but
% we are only going to take M samples out of the interpolator.  So after
% the first y(m) point is computed we must increment by M to the next branch
% (instead of computing all L points for each input point).  So we skip M
% branches for each output point.  Once we go over L branches, the 
% history buffer is updated with the next new data point also, and the next
% branch used is circularly addressed back up to the top of the interpolator
% structure.
for m=1:Ntotal
    y(m) = sum(hf(cnt,:) .* hist);
    cnt = cnt+M;
    if(cnt > L)
        while(cnt > L)        % this will loop more than 1x for M>L
            cnt = cnt-L;      % circularly address to get next out branch
            hist = filter([0 1], 1, hist); % put next pt into hist buff
            if(n <= Lx)
                hist(1) = x(n);
                n=n+1;
            end
        end
    end
end

% do standard l/m resampler. zero stuff with L-1 zeros, filter, then
% decimate

x = x(1:end);
xr = kron(x, [1 zeros(1,L-1)]);  %upsample
yr = filter(hq,1,xr); % filter
yr = yr(1:M:end); % downsample


