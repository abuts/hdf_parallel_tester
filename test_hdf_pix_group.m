classdef test_hdf_pix_group < TestCase
    %Unit tests to validate hdf_pix_group class
    %
    
    properties
    end
    
    methods
        function obj = test_hdf_pix_group(varargin)
            if nargin == 0
                class_name = 'test_hdf_pix_group';
            else
                class_name = varargin{1};
            end
            obj = obj@TestCase(class_name);
        end
        function close_fid(obj,fid,file_h,group_id)
            H5G.close(group_id);
            if ~isempty(file_h)
                H5G.close(fid);
                H5F.close(file_h);
            else
                H5F.close(fid);
            end
        end
        
        
        function test_read_write(obj)
            f_name = [tempname,'.nxsqw'];
            [fid,group_id,file_h,data_version] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            clob2 = onCleanup(@()delete(f_name));
            
            arr_size = 100000;
            pix_writer = hdf_pix_group(group_id,arr_size,16*1024);
            assertTrue(exist(f_name,'file')==2);
            pix_alloc_size = pix_writer.max_num_pixels;
            chunk_size     = pix_writer.block_size;
            assertEqual(chunk_size,16*1024);
            assertTrue(pix_alloc_size >= arr_size);
            
            data = ones(9,100);
            pos = [2,arr_size/2,arr_size-size(data,2)];
            pix_writer.write_pixels(pos(1),data);
            
            pix_writer.write_pixels(pos(2),2*data);
            
            pix_writer.write_pixels(pos(3),3*data);
            clear pix_writer;
            
            
            pix_reader = hdf_pix_group(group_id);
            assertEqual(chunk_size,pix_reader.block_size);
            assertEqual(pix_alloc_size,pix_reader.max_num_pixels);
            
            
            pix1 = pix_reader.read_pixels(pos(1),size(data,2));
            pix2 = pix_reader.read_pixels(pos(2),size(data,2));
            pix3 = pix_reader.read_pixels(pos(3),size(data,2));
            
            assertEqual(single(data),pix1);
            assertEqual(single(2*data),pix2);
            assertEqual(single(3*data),pix3);
            
            clear pix_reader;
            clear clob1
            
            [fid,group_id,file_h,rec_version] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            
            assertEqual(data_version,rec_version);
            
            pix_reader = hdf_pix_group(group_id);
            pix3 = pix_reader.read_pixels(pos(3),size(data,2));
            pix2 = pix_reader.read_pixels(pos(2),size(data,2));
            pix1 = pix_reader.read_pixels(pos(1),size(data,2));
            
            
            
            assertEqual(single(data),pix1);
            assertEqual(single(2*data),pix2);
            assertEqual(single(3*data),pix3);

            clear pix_reader;
            
            clear clob1;
            clear clob2;
        end
    end
end

