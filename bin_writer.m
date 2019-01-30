function bin_writer(block_size,n_blocks,job_num)

nl = numlabs;
if ~exist('job_num','var')
    id = labindex;
else
    id  = job_num;
end
if id == nl
    return;
end

f_name = sprintf('block_%d.bin',id);

fh = fopen(f_name,'wb');
if fh<1
    error('PARALLEL_WRITER:io_error','Can not open file %s',f_name);
end
clob = onCleanup(@()fclose(fh));
contents = id*ones(9,block_size);
for i=1:n_blocks
    contents(2,:) = contents(2,:)*i;
    fwrite(fh,contents);
end
clear('clob');