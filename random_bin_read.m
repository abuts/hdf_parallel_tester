function [time,read_sz]=random_bin_read(filesize,block_size,n_blocks,job_num)


nl = numlabs;
if ~exist('job_num','var')
    id = labindex;
else
    id  = job_num;
end
if id == nl
    time = 0;
    read_sz = 0;
    return;
end
t0 = tic;

f_name = sprintf('block_%d.bin',id);

fh = fopen(f_name,'rb');
if fh<1
    error('PARALLEL_WRITER:io_error','Can not open file %s',f_name);
end
clob = onCleanup(@()fclose(fh));
%fseek(fh,0,'eof');
%fsize = ftell(fh);


pos = floor((filesize-block_size)*rand(1,n_blocks));
pos = sort(pos)*(9*4);
%stat = fseek(fh,pos(1),'bof');
%if stat ~=0
%    error('can not move to initial position')
%end
%pos = pos -(pos(1)+block_size*4*9);
% invalid = pos+block_size*(4*9)> fsize;
% if any(invalid)
%     disp(find(invalid));
% end
%pos(1) = 0;
read_sz = 0;
for i=1:n_blocks
    stat=fseek(fh,pos(i),'bof');
    if stat ~=0
        mess=ferror(fh,'clear');
        warning('can not move to the requested random position Err: %s',mess)

        continue;
    end
    cont = fread(fh,[9,block_size],'real*4');
    read_sz = read_sz+size(cont,2);
end

time = toc(t0);
clear('clob');
