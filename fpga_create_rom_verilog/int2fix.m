function a = int2fix(b,n)

%---------------------------------------
% Converts a int number into a fixed pt 
%   number represented by n bits
%
%  USAGE:
%   a = int2fix(b,n)
%
% b:  integer input
% n:  the number of bits (16,24,32,...)
%       (n =16 is by default)
%
% Author:  J.M. Shima
% Date:    11-18-99
%---------------------------------------

if(~exist('n') )
   n = 16;
end

a=b;
a = ( a<2^(n-1) ).*a + (a>=2^(n-1)).*(a-2^n);

a = a/2^(n-1);
