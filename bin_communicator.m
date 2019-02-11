function [time,read_size] = bin_communicator(block_size,n_blocks,job_num)
% block_size == chunk_size -- the size of a single i/o block
% n_blocks   -- number of blocks (chunks) defining the total file size as
%               block_size*n_blocks*n_workers
% job_num    -- debugging parameter used in serial execution to mimick the
%               mpi labindex. Not used in parallel execution
diary on
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
    clobW = onCleanup(@()fclose('all'));
    
    n_readers = nl-1;
    if n_readers == 0 % serial execution for debugging. All input files should be read by serial job.
        n_readers = 5; % fake workers
        fhr = cell(1,n_readers);
        for i=1:n_readers
            f_name = sprintf('block_%d.bin',i);
            
            fhr{i} = fopen(f_name,'rb');
            if fhr{i}<1
                error('PARALLEL_WRITER:io_error','Can not open file %s to read',f_name);
            end
        end
        clobR = onCleanup(@()par_clear(fhr));
        
    else
        l_name = sprintf('worker_%d.log',labindex);        
        fhr =  fopen(l_name,'w');
        fprintf('receiver started\n');
    end
    
    
    for i=1:n_blocks
        block = get_block(i,block_size,n_readers,fhr);
        fwrite(fh,block,'single');
    end
    
    read_size = ftell(fh)/(4*9);
else
    f_name = sprintf('block_%d.bin',id);
    
    fh = fopen(f_name,'rb');
    if fh<1
        error('PARALLEL_WRITER:io_error','Can not open file %s to read',f_name);
    end
    l_name = sprintf('worker_%d.log',labindex);
    fhl = fopen(l_name,'w');
    clob = onCleanup(@()fclose('all'));
    
    for i=1:n_blocks
        contents = fread(fh,[9,block_size],'*float32');
        fprintf(fhl,'sending block N%d\n',i);
        labSend(contents,1);
    end
    read_size = block_size*n_blocks;
    clear('clob');
end
time = toc(t0);

function block = get_block(n_block,chunk_size,n_parts,par)

%block_size = size(block);
if numel(par)<2
    get_data = @(i)(labReceive(i+1));
    check_exist = @(i)(labProbe(i+1));
    do_logging = true;
    fprintf('accignied mpi receivers\n');
    
else
    check_exist = @(i)(true);
    get_data = @(i)get_bin_data(par{i},(n_block-1)*chunk_size*4*9,chunk_size);
    do_logging = false;
end

n_received = 0;
chunks_cache = cell(1,n_parts);
while n_received~=n_parts
    if do_logging
        fprintf(' expecting block %d from all workers\n',n_block)
    end
    for i=1:n_parts
        if check_exist(i)
            chunks_cache{i} = get_data(i);
            n_received = n_received+1;
        end
    end
    if do_logging
        fprintf(' block %d received\n',n_block)
    end
    
end
block = [chunks_cache{:}];
%block = reshape(block ,9,chunk_size*n_parts);

function data= get_bin_data(fh,pos,chunk_size)
fseek(fh,pos,'bof');
data = fread(fh,[9,chunk_size],'*float32');

function par_clear(fh_list)
for i=1:numel(fh_list)
    fclose(fh_list{i});
end