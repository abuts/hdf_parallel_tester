function eval_io_speed(disable_binary)
% evaluate speed of binary and hdf io operations with different types of
% settings
block_size = [64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144,524288];
N_att = 10;
minN_blocks = 10;
HDF_chunk_size = 64*1024;
fprintf('HDF chunk size: %dKPix\n',HDF_chunk_size/1024);
if ~exist('disable_binary','var')
    disable_binary = false;
end
for n_block = 1:numel(block_size)
    
    nblocks = floor(block_size(end)*minN_blocks/block_size(n_block));
    file_size = nblocks*block_size(n_block);
    
    if disable_binary
        fprintf('Block size: %8d :Speed(MPix/sec): ',block_size(n_block));
    else
        t1 =0 ;
        tot_size = 0;
        for i = 1:N_att
            if exist('block_2.bin','file')==2
                delete('block_2.bin');
            end
            [tr,wr_sz]=bin_writer(block_size(n_block),nblocks ,2);
            t1=t1+tr;
            tot_size = tot_size+wr_sz;
        end
        
        
        fprintf('Block size: %8d :Speed(MPix/sec): bin Write: %4.1f:',...
            block_size(n_block),(tot_size/(1024*1024))/t1);
        
        
        t1=0;
        tot_size = 0;
        for i=1:N_att
            
            [tr,read_sz]=random_bin_read(file_size,block_size(n_block),floor(nblocks/8),2);
            t1 = t1+tr;
            tot_size = tot_size+read_sz;
        end
        fprintf(' Read: %4.1f:',(tot_size/t1/(1024*1024)));
    end
    
    t2=0;
    tot_size = 0;    
    for i = 1:N_att
        if exist('block_2.hdf','file')==2
            delete('block_2.hdf');
        end
        
        [tr,write_sz]=hdf_writer(block_size(n_block),nblocks,2,HDF_chunk_size);
        t2= t2+tr;
        tot_size = tot_size+write_sz;
    end    
    fprintf(' HDF Write: %4.1f:',(tot_size/(1024*1024))/t2 );
    %
    t2= 0;
    tot_size = 0;
    for i=1:N_att
        [tr,read_sz]=random_hdf_read(file_size,block_size(n_block),floor(nblocks/8),2);
        t2 = t2+tr;
        tot_size = tot_size+read_sz;
    end
    
    fprintf(' Read:  %4.1f\n',(tot_size/t2/(1024*1024)) );
end
if exist('block_2.bin','file')==2
    delete('block_2.bin');
end

delete('block_2.hdf');