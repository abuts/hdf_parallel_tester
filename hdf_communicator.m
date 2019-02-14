function [time,read_size] = hdf_communicator(chunk_size,n_blocks,job_num)
% block_size == chunk_size -- the size of a single i/o block
% n_blocks   -- number of blocks (chunks) defining the total file size as
%               block_size*n_blocks*n_workers
% job_num    -- debugging parameter used in serial execution to mimick the
%               mpi labindex. Not used in parallel execution
%diary on
do_logging = false;
nl = numlabs;
if ~exist('job_num','var')
    id = labindex-1;
else
    id  = job_num-1;
end
t0 = tic;


%
if id == 0
    f_name = 'targ_file.hdf';
	n_pixels = n_blocks*chunk_size*(nl-1);    
    [fid,group_id] = open_or_create_nxsqw_head(f_name);
    clob1 = onCleanup(@()par_clear({group_id,fid}));

    hdf_w = hdf_pix_group(group_id,n_pixels,chunk_size);
    clobW = onCleanup(@()par_clear({hdf_w,group_id,fid}));
    %
    n_readers = nl-1;
    if n_readers == 0 % serial execution for debugging. All input files should be read by serial job.
        n_readers = 5; % fake workers
        fhr = cell(3,n_readers);
        for i=1:n_readers
            f_name = sprintf('block_%d.hdf',i);
            
            [fhr{1,i},fhr{2,i}] = open_or_create_nxsqw_head(f_name);
			fhr{3,i} = hdf_pix_group(fhr{2,i});
        end
        clobR = onCleanup(@()par_clear(fhr));
        n_blocks = n_blocks/n_readers;
    else
        if do_logging
            l_name = sprintf('worker_%d.log',labindex);
            fhr =  fopen(l_name,'w');
            fprintf(fhr,'receiver started\n');
        else
            fhr = [];
        end
    end
    
    superblock = chunk_size*n_readers;
    for i=1:n_blocks
        block = get_block(i,chunk_size,n_readers,fhr,do_logging);
        hdf_w.write_pixels((i-1)*superblock+1,block);
    end
    read_size = superblock*n_blocks;
else
    
    f_name = sprintf('block_%d.hdf',id);
    [fid,gr_id]   =open_or_create_nxsqw_head(f_name);
    hdf_r = hdf_pix_group(gr_id);    
    clob = onCleanup(@()par_clear({hdf_r,gr_id,fid}));
    
    for i=1:n_blocks
        contents = hdf_r.read_pixels((i-1)*chunk_size+1,chunk_size);
        if do_logging
            fprintf(fhl,'sending block N%d\n',i);
        end
        labSend(contents,1,i);
    end
    read_size = chunk_size*n_blocks;
    clear('clob');
end
time = toc(t0);

function block = get_block(n_block,chunk_size,n_parts,par,do_logging)

%block_size = size(block);
if numel(par)==1 || isempty(par)
    get_data = @(i)(labReceive(i+1,n_block));
    check_exist = @(i)(labProbe(i+1,n_block));
    if do_logging        
        fprintf(par,'accignied mpi receivers\n');
    end
    
else
    check_exist = @(i)(true);
    get_data = @(i)get_hdf_data(par{3,i},(n_block-1)*chunk_size+1,chunk_size);
    do_logging = false;
end

n_received = 0;
chunks_cache = cell(1,n_parts);
while n_received~=n_parts
    if do_logging
        fprintf(par,' expecting block %d from all workers\n',n_block);
    end
    for i=1:n_parts
        if check_exist(i)
            chunks_cache{i} = get_data(i);
            n_received = n_received+1;
        end
    end
    if do_logging
        fprintf(par,' received %d out of %d parts\n',n_received,n_parts);
    end
    
end
block = [chunks_cache{:}];
%block = reshape(block ,9,chunk_size*n_parts);

function data= get_hdf_data(fh,pos,chunk_size)
data = fh.read_pixels(pos,chunk_size);

function par_clear(fh_list)
for i=1:numel(fh_list)
    delete(fh_list{i});
end