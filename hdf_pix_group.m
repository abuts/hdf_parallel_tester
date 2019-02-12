classdef hdf_pix_group < handle
    % Helper class to control I/O operations over pixels stored in hdf sqw
    % file.
    
    properties(Dependent)
        % the number of pixels allowed to be stored in the dataset
        max_num_pixels;
        % The size of the chunk providing access to
        % the pixel dataset
        chunk_size
        % the min/max values of the pixels data, stored in the dataset
        pix_range
        %
        %
        cache_nslots;
        cache_size; % in pixels
    end
    properties(Access=private)
        chunk_size_   =  1024*32;   % decent io speed starts from 16*1024
        cache_nslots_   =  521 ; % in block sizes
        cache_size_     =  -1 ; % in bytes
        max_num_pixels_  = -1;
        num_pixels_      = 0;
        %
        pix_group_id_     = -1;
        file_space_id_    = -1;
        pix_data_id_      = -1;
        pix_dataset_      = -1;
        io_mem_space_     = -1;
        io_chunk_size_    = 0;
        
        %
        pix_range_ = [inf,-inf;inf,-inf;inf,-inf;inf,-inf];
    end
    
    methods
        function obj = hdf_pix_group(fid,n_pixels,chunk_size)
            % Open existing or create new pixels group in existing hdf file.
            %
            % If the group does not exist, additional parameters describing
            % the pixel array size have to be specified. If it does exist,
            % all input parameters except fid will be ignored
            %Usage:
            % pix_wr = hdf_pixel_group(fid,n_pixels,[chunk_size]);
            %          creates pixel group to store specified number of
            %          pixels.
            % chunk_size -- if present, specifies the chunk size of the
            %               chunked hdf dataset to create. If not, default
            %               class value is used
            %          If the pixel dataset exists, and  its sizes are
            %          different from the values, provided with this
            %          command, the dataset will be recreated with new
            %          parameters. Old dataset contents will be destroyed.
            %
            % pix_wr = hdf_pixel_group(fid); open existing pixels group
            %                                for IO operations. Throws if
            %                                the group does not exist.
            %          a writing (if any) occurs into an existing group
            %          allowing to modify the contents of the pixel array.
            %
            if exist('n_pixels','var')|| exist('chunk_size','var')
                pix_size_redefined = true;
            else
                pix_size_redefined = false;
            end
            if exist('chunk_size','var')
                obj.chunk_size_ = chunk_size;
            else
                chunk_size = obj.chunk_size_;
            end
            
            group_name = 'pixels';
            
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
                obj.chunk_size_ = h5_chunk_size(1);
                if pix_size_redefined
                    n_pixels =  obj.get_extended_npix_(n_pixels,chunk_size);
                    if obj.chunk_size_ ~= chunk_size
                        error('HDF_PIX_GROUP:invalid_argument',...
                            'Current chunk %d, new chunk %d. Can not change the chunk size of the existing dataset.',...
                            obj.chunk_size_,chunk_size)
                    elseif obj.max_num_pixels_ ~=n_pixels
                        H5D.set_extent(obj.pix_dataset_,[n_pixels,9]);
                        obj.max_num_pixels_ = n_pixels;
                        obj.file_space_id_  = H5D.get_space(obj.pix_dataset_);                        
                    end
                end
                pix_dapl_id = H5D.get_access_plist(obj.pix_dataset_);
                [obj.cache_nslots_,obj.cache_size_]=H5P.get_chunk_cache(pix_dapl_id);
                %chunk_size = obj.chunk_size_;
            else
                if nargin<1
                    error('HDF_PIX_GROUP:invalid_argument',...
                        'the pixels group does not exist but the size of the pixel dataset is not specified')
                end
                obj.pix_group_id_ = H5G.create(fid,group_name,10*numel(group_name));
                write_attr_group(obj.pix_group_id_,struct('NX_class','NXdata'));
                
                create_pix_dataset_(obj,group_name,n_pixels,chunk_size);
            end
            block_dims = [obj.chunk_size_,9];
            obj.io_mem_space_ = H5S.create_simple(2,block_dims,block_dims);
            obj.io_chunk_size_ = obj.chunk_size_;
            %H5P.close(dcpl_id);
            %H5P.close(pix_dapl_id );
            
        end
        %
        function write_pixels(obj,start_pos,pixels)
            block_dims = [size(pixels,2),9];
            if block_dims(1)<=0
                return;
            end
            if isa(pixels,'single')
                buff = pixels;
            else
                buff = single(pixels);
            end
            
            if obj.io_chunk_size_ ~= block_dims(1)
                H5S.set_extent_simple(obj.io_mem_space_,2,block_dims,block_dims);
                obj.io_chunk_size_ = block_dims(1);
            end
            
            block_start = [start_pos-1,0];
            if start_pos+block_dims(1)-1 > obj.max_num_pixels_
                error('HDF_PIX_GROUP:invalid_argument',...
                    'The final position of pixels to write (%d) exceeds the allocated pixels storage (%d)',...
                    start_pos+block_dims(1),obj.max_num_pixels_)
            end
            
            H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start,[],[],block_dims);
            H5D.write(obj.pix_dataset_,'H5ML_DEFAULT',obj.io_mem_space_,obj.file_space_id_,'H5P_DEFAULT',buff);
        end
        %
        function [pixels,start_pos,n_pix]= read_pixels(obj,start_pos,n_pix)
            % read pixel information specified by pixels starting position
            % and the sizes of the pixels blocks
            %
            % n_pix always > 0 and numel(start_pos)== numel(n_pix) (or n_pix == 1)
            % for algorithm to be correct
            if numel(start_pos) == 1
                block_start = [start_pos-1,0];
                pix_chunk_size  = [n_pix,9];
                
                if obj.io_chunk_size_ ~= n_pix
                    H5S.set_extent_simple(obj.io_mem_space_,2,pix_chunk_size,pix_chunk_size);
                    obj.io_chunk_size_ = n_pix;
                end
                
                
                H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start,[],[],pix_chunk_size);
                pixels=H5D.read(obj.pix_dataset_,'H5ML_DEFAULT',obj.io_mem_space_,obj.file_space_id_,'H5P_DEFAULT');
                
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
                pix_chunk_size = [npix,pix_sizes];
                
                H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start(1,:),[],[],pix_chunk_size(1,:));
                
                if npix(1)+npix(2) > obj.chunk_size_
                    selected_size = npix(1);
                    last_block2select = 1;
                else
                    npix_tot = cumsum(npix);
                    last_block2select = find(npix_tot > obj.chunk_size_,1)-1;
                    if isempty(last_block2select)
                        last_block2select=n_blocks;
                        %elseif last_block2select == 1 this is covered by npix(1)+npix(2) > obj.chunk_size_
                    end
                    chunk_ind = 2:last_block2select;
                    
                    arrayfun(@(ind)H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_OR',block_start(ind,:),[],[],pix_chunk_size(ind,:)),chunk_ind);
                    selected_size = npix_tot(last_block2select);
                end
                
                %                 selected_size = pix_chunk_size(1,1);
                %                 n_blocks_selected = 1;
                %                 if selected_size < obj.cache_size
                %                     for i=2:n_blocks
                %                         next_size = selected_size+pix_chunk_size(i,1);
                %                         if selected_size>obj.chunk_size_
                %                             break;
                %                         end
                %                         selected_size = next_size;
                %                         H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_OR',block_start(i,:),[],[],pix_chunk_size(i,:));
                %                         n_blocks_selected = n_blocks_selected +1;
                %                     end
                %                 end
                start_pos = start_pos(last_block2select+1:end);
                if numel(n_pix) > 1
                    n_pix = n_pix(last_block2select+1:end);
                end
                
                mem_block_size = [selected_size,9];
                if obj.io_chunk_size_ ~= selected_size
                    H5S.set_extent_simple(obj.io_mem_space_,2,mem_block_size,mem_block_size);
                    obj.io_chunk_size_ = selected_size;
                end
                
                pixels=H5D.read(obj.pix_dataset_,'H5ML_DEFAULT',obj.io_mem_space_,obj.file_space_id_,'H5P_DEFAULT');
                
                
            end
        end
        
        %------------------------------------------------------------------
        function sz = get.chunk_size(obj)
            sz  = obj.chunk_size_;
        end
        function np = get.max_num_pixels(obj)
            np  = obj.max_num_pixels_;
        end
        function range = get.pix_range(obj)
            range  = obj.pix_range_;
        end
        function sz = get.cache_size(obj)
            sz = obj.cache_size_/(36);
        end
        function sz = get.cache_nslots(obj)
            sz = obj.cache_nslots_;
        end
        
        %------------------------------------------------------------------
        function delete(obj)
            % close all and finish
            if ~isempty(obj.io_mem_space_)
                H5S.close(obj.io_mem_space_);
            end
            if obj.pix_data_id_ ~= -1
                H5T.close(obj.pix_data_id_);
                obj.pix_data_id_ = -1;
            end
            close_pix_dataset_(obj);
            %
            if obj.pix_group_id_ ~= -1
                H5G.close(obj.pix_group_id_);
            end
        end
        
    end
    methods(Access = private)
        %
        function mem_space_id = get_cached_mem_space(obj,block_dims)
            % function extracts memory space object from a data buffer
            if obj.io_chunk_size_ ~= block_dims(1)
                H5S.set_extent_simple(obj.io_mem_space_,2,block_dims,block_dims);
                obj.io_chunk_size_ = block_dims(1);
            end
            mem_space_id = obj.io_mem_space_;
        end
        %
        function close_pix_dataset_(obj)
            if obj.file_space_id_ ~= -1
                H5S.close(obj.file_space_id_);
                obj.file_space_id_ = -1;
            end
            if obj.pix_dataset_ ~= -1
                H5D.close(obj.pix_dataset_);
                obj.pix_dataset_ = -1;
            end
        end
        %
        function  create_pix_dataset_(obj,dataset_name,n_pixels,chunk_size)
            %
            obj.max_num_pixels_ = obj.get_extended_npix_(n_pixels,chunk_size);
            dims = [obj.max_num_pixels_,9];
            chunk_dims = [chunk_size,9];
            %
            % size of the pixel cache
            pn = 521; %primes(2050);
            obj.cache_nslots_ = pn(end);
            cache_n_bytes = obj.cache_nslots_*chunk_size*9*4;
            %cache_n_bytes     = 0; %chunk_size*9*4;
            obj.cache_size_   = cache_n_bytes;
            
            
            dcpl_id = H5P.create('H5P_DATASET_CREATE');
            H5P.set_chunk(dcpl_id, chunk_dims);
            pix_dapl_id = H5P.create('H5P_DATASET_ACCESS');
            H5P.set_chunk_cache(pix_dapl_id,obj.cache_nslots_,cache_n_bytes,1);
            
            obj.file_space_id_ = H5S.create_simple(2,dims,[H5ML.get_constant_value('H5S_UNLIMITED'),9]);
            
            obj.pix_dataset_= H5D.create(obj.pix_group_id_,dataset_name,...
                obj.pix_data_id_ ,obj.file_space_id_,...
                'H5P_DEFAULT',dcpl_id,pix_dapl_id);
            
        end
    end
    methods(Static,Access=private)
        function npix = get_extended_npix_(n_pixels,chunk_size)
            % get number of pixels proportional to a chunk size.
            n_blocks = n_pixels/chunk_size ;
            if rem(n_pixels,chunk_size)>0
                n_blocks = floor(n_blocks) +1;
                
            end
            npix = chunk_size*n_blocks;
        end
        
    end
end

