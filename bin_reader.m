function bin_reader(block_size,n_blocks,job_num)

nl = numlabs;
if ~exist('job_num','var')
    id = labindex-1;
else
    id  = job_num-1;
end
%
if id == 0
    f_name = 'targ_file.bin';
    fh = fopen(f_name,'wb');
    if fh<1
        error('PARALLEL_WRITER:io_error','Can not open file %s to write',f_name);
    end
    n_parts = nl-1;
    if n_parts == 0
        parallel = false;
        n_parts = 5;
    else
        parallel = true;        
    end
    block = zeros(9,block_size*n_parts);
    for i=1:n_blocks
        block = get_block(i,block,n_parts,parallel);
        fwrite(fh,block );
    end
else
    
    f_name = sprintf('block_%d.bin',id);
    
    fh = fopen(f_name,'rb');
    if fh<1
        error('PARALLEL_WRITER:io_error','Can not open file %s to read',f_name);
    end
    clob = onCleanup(@()fclose(fh));
    
    for i=1:n_blocks
        contents = fread(fh,[9,block_size]);
        labSend(contents,1,i);
    end
    clear('clob');
end

function block = get_block(n_block,block,n_parts,parallel)

block_size = size(block);
chunk_size = block_size(2)/n_parts;
if parallel
    get_data = @(i)(labReceive(i,n_block));
    check_exist = @(i)(labProbe(i,n_block));
else
    f_name = sprintf('block_%d.bin',id);
    
    fh = fopen(f_name,'rb');
    if fh<1
        error('PARALLEL_WRITER:io_error','Can not open file %s to read',f_name);
    end    
    clob = onCleanup(@()fclose(fh));
    
    get_data = @(i)(fread(fh,[9,block_size]));    
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


