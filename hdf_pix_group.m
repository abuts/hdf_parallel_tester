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
        block_size_   =  1024; % decent io speed starts from 16*1024
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
        function pixels= read_pixels(obj,start_pos,n_pix)
            block_start = [start_pos-1,0];
            pix_block_size  = [n_pix,9];
            
            mem_space_id = H5S.create_simple(2,pix_block_size,[]);
            H5S.select_hyperslab(obj.file_space_id_,'H5S_SELECT_SET',block_start,[],[],pix_block_size);
            pixels=H5D.read(obj.pix_dataset_,'H5ML_DEFAULT',mem_space_id,obj.file_space_id_,'H5P_DEFAULT');
            H5S.close(mem_space_id);
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

