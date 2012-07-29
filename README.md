This script generates an arbitrary number of files using file names with random data that follow a specific naming convention. 

**The *generate.pl* script**

The perl app that generates all the test data. It reads data from the randomizable-data directory and then randomly puts that data together into file names and then writes out sample files in the generated-files directory.

**The *randomizable-data* directory**

This folder contains simple text files that include the values that should be used for random data. Each file has a header line that describes what data is present and then each line of a particular data file has as many values as the randomizer in generate.pl should use. You can add as many values in each files as you'd like, and you can add as many files as you like if you need new "data types" to put into your generated file names.

**The *generated-files* folder**

The folder in which all the files are generated; you should delete the contents of this folder (not the actual folder, though) before re-running the script.