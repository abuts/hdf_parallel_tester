function [time,read_size] = bin_communicator(block_size,n_blocks,job_num)

nl = numlabs;
if ~exist('job_num','var')
    id = labindex-1;
else
    id  = job_num-1;
end
t0 = tic;
%
if id == 0
    f_name = 'targ_file.bin';
    fh = fopen(f_name,'wb');
    if fh<1
        error('PARALLEL_WRITER:io_error','Can not open file %s to write',f_name);
    end
    clobW = onCleanup(@()fclose(fh));
    
    n_parts = nl-1;
    if n_parts == 0 % serial execution. All input files should be read by serial job.
        n_parts = 5;
        fhr = cell(1,n_parts);
        for i=1:n_parts
            f_name = sprintf('block_%d.bin',i);
            
            fhr{i} = fopen(f_name,'rb');
            if fhr{i}<1
                error('PARALLEL_WRITER:io_error','Can not open file %s to read',f_name);
            end
        end
        clobR = onCleanup(@()par_clear(fhr));
        
    else
        fhr = [];
    end
    block = single(ones(9,block_size*n_parts));
    
    
    for i=1:n_blocks
        block = get_block(i,block_size,block,n_parts,fhr);
    end
    fwrite(fh,block );
    read_size = ftell(fh)/(4*9);
else
    
    f_name = sprintf('block_%d.bin',id);
    
    fh = fopen(f_name,'rb');
    if fh<1
        error('PARALLEL_WRITER:io_error','Can not open file %s to read',f_name);
    end
    clob = onCleanup(@()fclose(fh));
    
    for i=1:n_blocks
        contents = fread(fh,[9,block_size],'*float32');
        labSend(contents,1);
    end
    read_size = block_size*n_blocks;
    clear('clob');
end
time = toc(t0);

function block = get_block(n_block,block1_size,block,n_parts,par)

block_size = size(block);
chunk_size = block_size(2)/n_parts;
if isempty(par)
    get_data = @(i)(labReceive(i+1,n_block));
    check_exist = @(i)(labProbe(i+1,n_block));
else
    check_exist = @(i)(true);
    get_data = @(i)get_bin_data(par{i},(n_block-1)*block1_size*4*9,chunk_size);
end

n_received = 0;
while n_received~=n_parts
    for i=1:n_parts
        if check_exist(i)
            block(:,(i-1)*chunk_size+1:i*chunk_size) = get_data(i);
            n_received = n_received+1;
        end
    end
end

function data= get_bin_data(fh,pos,chunk_size)
fseek(fh,pos,'bof');
data = fread(fh,[9,chunk_size],'*float32');

function par_clear(fh_list)
for i=1:numel(fh_list)
    fclose(fh_list{i});
end