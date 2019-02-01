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
        function close_fid(obj,fid,file_h,group_id,f_name)
            H5G.close(group_id);
            if ~isempty(file_h)
                H5G.close(fid);
                H5F.close(file_h);
            else
                H5F.close(fid);
            end
            delete(f_name);
        end
        
        
        function test_read_write(obj)
            f_name = [tempname,'.nxsqw'];
            [fid,group_id,file_h] = create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id,f_name));
            
            arr_size = 100000;
            pix_writer = hdf_pix_group(group_id,arr_size);
            assertTrue(exist(f_name,'file')==2);
            
            data = ones(9,100);
            pix_writer.write_pixels(2,data);
            
            pix_writer.write_pixels(arr_size/2,5*data);
            
            pix_writer.write_pixels(arr_size-size(data,2),10*data);
            clear pix_writer;
            clear clob1
            
            
        end
    end
end

