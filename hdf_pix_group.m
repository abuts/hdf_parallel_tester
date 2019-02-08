classdef hdf_pix_group < handle
    % Helper class to control I/O operations over pixels stored in hdf sqw
    % file.
    
    properties(Dependent)
        % the number of pixels allowed to be stored in the dataset
        max_num_pixels;
        % The size of the chunk providing access to
        % the pixel dataset
        block_size
        % the min/max values of the pixels data, stored in the dataset
        pix_range
    end
    properties(Access=private)
        block_size_   =  1024*32;   % decent io speed starts from 16*1024
        cache_nslots_   =  521 ; % in block sizes
        max_num_pixels_   = -1;
        num_pixels_       = 0;
        %
        pix_group_id_     = -1;
        file_space_id_    = -1;
        pix_data_id_      = -1;
        pix_dataset_      = -1;
        
        %
        pix_range_ = [inf,-inf;inf,-inf;inf,-inf;inf,-inf];
    end
    
    methods
        function obj = hdf_pix_group(fid,n_pixels,block_size)
            % Open existing or create new pixels group in existing hdf file.
            %
            % If the group does not exist, additional parameters describing
            % the pixel array size have to be specified. If it does exist,
            % all input parameters except fid will be ignored
            %Usage:
            % pix_wr = hdf_pixel_group(fid,n_pixels,[block_size]);
            %          % creates pixel group to store specified number of pixels
            % block_size -- if present, specifies the chunk size of the
            %               chunked hdf dataset to create.
            % pix_wr = hdf_pixel_group(fid); open existing pixels group
            %                                for IO operations. Throws if
            %                                the group does not exist.
            %
            if exist('block_size','var')
                obj.block_size_ = block_size;
            else
                block_size = obj.block_size_;
            end
            
            group_name = 'pixels';
            cache_n_bytes = obj.cache_nslots_*block_size*9*4;
            
            obj.pix_data_id_ = H5T.copy('H5T_NATIVE_FLOAT');
            if H5L.exists(fid,group_name,'H5P_DEFAULT')
                obj.pix_group_id_ = H5G.open(fid,group_name);
                if obj.pix_group_id_<0
                    error('HDF_PIX_GROUP:runtime_error',...
                        'can not open pixels group');
                end
                obj.pix_dataset_ = H5D.open(obj.pix_group_id_,group_name);
                if obj.pix_dataset_<0
                    error('HDF_PIX_GROUP:runtime_error',...
                        'can not open pixels dataset');
                end
                obj.file_space_id_  = H5D.get_space(obj.pix_dataset_);
                if obj.file_space_id_<0
                    error('HDF_PIX_GROUP:runtime_error',...
                        'can not retrieve pixels datasets dataspace');
                end
                [~,~,h5_maxdims] = H5S.get_simple_extent_dims(obj.file_space_id_);
                obj.max_num_pixels_ = h5_maxdims(1);
                if h5_maxdims(2) ~= 9
                    error('HDF_PIX_GROUP:runtime_error',...
                        'wrong size of pixel dataset. dimenison 1 has to be 9 but is: %d',...
                        h5_maxdims(2));
                end
                dcpl_id=H5D.get_create_plist(obj.pix_dataset_);
                [~,h5_chunk_size] = H5P.get_chunk(dcpl_id);
                obj.block_size_ = h5_chunk_size(1);
                %block_size = obj.block_size_;
            else
                if nargin<1
                    error('HDF_PIX_GROUP:invalid_argument',...
                        'the pixels group does not exist but the size of the pixel dataset is not specified')
                end
                
                n_blocks = n_pixels/block_size ;
                if rem(n_pixels,block_size)>0
                    n_blocks = floor(n_blocks) +1;
                end
                obj.max_num_pixels_ = block_size*n_blocks;
                dims = [obj.max_num_pixels_,9];
                chunk_dims = [block_size,9];
                %
                obj.pix_group_id_ = H5G.create(fid,group_name,10*numel(group_name));
                write_attr_group(obj.pix_group_id_,struct('NX_class','NXdata'));
                
                dcpl_id = H5P.create('H5P_DATASET_CREATE');
                H5P.set_chunk(dcpl_id, chunk_dims);
                
                obj.file_space_id_ = H5S.create_simple(2,dims,dims);
                
                obj.pix_dataset_= H5D.create(obj.pix_group_id_,group_name,obj.pix_data_id_ ,obj.file_space_id_,dcpl_id);
                
            end
            
            H5P.close(dcpl_id);
            pix_daspl = H5D.get_access_plist(obj.pix_dataset_);
            H5P.set_chunk_cache(pix_daspl,obj.cache_nslots_,cache_n_bytes,1);
            H5P.close(pix_daspl);
            
        end
        %
        function write_pixels(obj,start_pos,pixels)
            block_dims = fliplr(size(pixels));
            if block_dims(2) ~=9
                error('HDF_PIX_GROUP:invalid_argument',...
                    'Pixel array size should be [9,npix], but actually it is [%d,%d]',...
                    block_dims(2),block_dims(1));
                
            end
            if block_dims(1)<=0
                return;
            end
            if isa(pixels,'single')
                buff = pixels;
            else
                buff = single(pixels);
            end
            mem_space_id = H5S.create_simple(2,block_dims,block_dims);
            
            block_start = [start_pos-1,0];
            if start_pos+block_dims(1)-1 > obj.max_num_pixels_
                error('HDF_PIX_GROUP:invalid_argument',...
                    'The final position of pixels to write (%d) exceeds the allocated pixels storage (%d)',...
                    start_pos+block_dims(1),obj.max_num_pixels_)
            end
            
            H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start,[],[],block_dims);
            H5D.write(obj.pix_dataset_,'H5ML_DEFAULT',mem_space_id,obj.file_space_id_,'H5P_DEFAULT',buff);
            H5S.close(mem_space_id);
        end
        %
        function [pixels,start_pos,n_pix]= read_pixels(obj,start_pos,n_pix)
            % read pixel information specified by pixels starting position
            % and the sizes of the pixels blocks
            
            %
            if numel(start_pos) == 1
                block_start = [start_pos-1,0];
                pix_block_size  = [n_pix,9];
                
                mem_space_id = H5S.create_simple(2,pix_block_size,[]);
                H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start,[],[],pix_block_size);
                pixels=H5D.read(obj.pix_dataset_,'H5ML_DEFAULT',mem_space_id,obj.file_space_id_,'H5P_DEFAULT');
                H5S.close(mem_space_id);
                start_pos = [];
            else
                if numel(n_pix) ~=numel(start_pos)
                    if numel(n_pix)==1
                        npix = ones(numel(start_pos),1)*n_pix;
                    else
                        error('HDF_PIX_GROUP:invalid_argument',...
                            'number of pix blocks (%d) has to be equal to the number of pix positions (%d) or be equal to 1',...
                            numel(n_pix),numel(start_post));
                    end
                else
                    if size(n_pix,2) ~=1
                        npix = n_pix';
                    else
                        npix = n_pix;
                    end
                end
                if size(start_pos,2) ~=1
                    block_start = start_pos'-1;
                else
                    block_start = start_pos-1;
                end
                
                n_blocks = numel(start_pos);
                block_start = [block_start,zeros(n_blocks,1)];
                pix_sizes = ones(n_blocks,1)*9;
                pix_block_size = [npix,pix_sizes];
                
                H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start(1,:),[],[],pix_block_size(1,:));
                cur_size = pix_block_size(1,1);
                n_blocks_selected = 1;
                if cur_size < obj.block_size_
                    for i=2:n_blocks
                        next_size = cur_size+pix_block_size(i,1);
                        if cur_size>obj.block_size_
                            break;
                        end
                        cur_size = next_size;
                        H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_OR',block_start(i,:),[],[],pix_block_size(i,:));
                        n_blocks_selected = n_blocks_selected +1;
                    end
                end
                start_pos = start_pos(n_blocks_selected+1:end);
                if numel(n_pix) > 1
                    n_pix = n_pix(n_blocks_selected+1:end);
                end
                
                mem_block_size = [cur_size,9];
                mem_space_id = H5S.create_simple(2,mem_block_size,[]);
                pixels=H5D.read(obj.pix_dataset_,'H5ML_DEFAULT',mem_space_id,obj.file_space_id_,'H5P_DEFAULT');
                H5S.close(mem_space_id);
                
            end
        end
        
        %------------------------------------------------------------------
        function sz = get.block_size(obj)
            sz  = obj.block_size_;
        end
        function np = get.max_num_pixels(obj)
            np  = obj.max_num_pixels_;
        end
        function range = get.pix_range(obj)
            range  = obj.pix_range_;
        end
        %------------------------------------------------------------------
        function delete(obj)
            % close all and finish
            if obj.file_space_id_ > 0
                H5S.close(obj.file_space_id_);
            end
            if obj.pix_data_id_ > 0
                H5T.close(obj.pix_data_id_);
            end
            if obj.pix_dataset_ > 0
                H5D.close(obj.pix_dataset_);
            end
            if obj.pix_group_id_ > 0
                H5G.close(obj.pix_group_id_);
            end
        end
        
    end
end

