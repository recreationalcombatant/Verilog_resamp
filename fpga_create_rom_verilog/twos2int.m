function a=twos2int(b,N)

%-----------------------------------------------------------------------
% Converts 2's complement fixed-pt numbers back into unsigned ints of N bits
% works on real or imaginary numbers.  Input must be in range [-1,1)
%
% USAGE:
%  a = twos2int(b,N)
% 
% N: number of bits
% b: vector of unsigned ints
%
% Author: J.M. Shima
%
% Date: 6/1/00
%
%----------------------------------------------------------------------

b = fxquant(b, N, 'round', 'sat');
if(isreal(b))
   
   a = (b<0).*( fix(b.*2^(N-1)) + 2^N) + (b>=0).*( fix(b.*2^(N-1)) );
 
else
   c = real(b);
   d = imag(b);
   
   a = (b<0).*( fix(b.*2^(N-1)) + 2^N) + (b>=0).*( fix(b.*2^(N-1)) );
   
end
 
    