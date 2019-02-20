#pragma once

#include <mex.h>
#include <string>
#include <sstream>


enum input_types {
	close_file,
	read_data_ready,
	open_and_read_data
};
/* The structure defines the position of the pixel dataset in an nxsqw hdf file and consist of
   the name of the file and the full name of the group, containing pixels dataset*/
struct input_file {
	/* the name of hdf file to access pixels */
	std::string filename;
	/*the name of the group, containing pixels information */
	std::string groupname;

	/* check if the name and group name of other input file are equal to the current file*/
	bool equal(input_file &other_file) {
		if (other_file.filename == this->filename && other_file.groupname == this->groupname)
			return true;
		else return false;
	}
	bool is_destructor() {
		if (this->filename == std::string("close") || this->groupname == std::string("close"))return true;
		else return false;
	}
};
