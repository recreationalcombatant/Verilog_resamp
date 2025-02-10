function write_ram_coe(fname, vec)

fid = fopen(fname, 'w');
fprintf(fid, 'MEMORY_INITIALIZATION_RADIX=10;\n');
fprintf(fid, 'MEMORY_INITIALIZATION_VECTOR=\n');
fprintf(fid, '%d,\n', vec(1:end-1));
fprintf(fid, '%d;\n',vec(end));
fclose(fid);

