# bdeshake
Script to batch deshake videos using virtualdub and deshaker plugin. This is a single-file project, description included in the file.

# Batch deshaker #

Deshakes (stabilizes) one video file or files of a directory to the same directory with .ds.mp4 name extension

## Prerequisites ##

0. Windows 7 or newer
1. install virtualdub -- see http://virtualdub.org/
2. install deshaker plugin -- see http://www.guthspot.se/video/deshaker.htm
3. install ffmpeg -- see http://ffmpeg.org/
4. install x264 external encoder named 'x264' with params '-B 18000 --profile baseline --preset slow --ref 5 --level 4.1 --keyint 24 --tune film --bluray-compat --stitchable --b-pyramid strict --demuxer raw --input-csp i420 --input-res %(width)x%(height) --fps %(fpsnum)/%(fpsden) -o "%(tempvideofile)" -' output '%(outputname).264'
5. install neroAacEnc external encoder named 'neroaac' with params '-q 0.80 -ignorelength -if - -of "%(tempaudiofile)"', output '%(outputname).m4a'
6. create mp4 external encoder set in virtualdub named 'MP4' containing 
	'x264' and 'neroaac'

## Installation ##

1. Save this single file to anywhere in your windows machine.
2. Edit global settings below:
	* ffmpegbase is the path to the installed ffmpeg
	* commandbase is the path to the installed virtualdub
	* change any other settings if you want
3. Review extensions and template files (if you know virtualdub scripting)

If template directory does not exists, it will be created and it's content initialized from this 
script. Embedded template files will be extracted only this times. If you modify the template files 
in the template directory, the modified files will be used.
	
## Using ##

 bdeshake.cmd filename [-t] [-o]
 
... or simply drop a directory to the script for default batch process.

Skips existing output files, unless -o switch specified.
creates %filename%.ds.jobs temp file
Detect interlaced files into %int%

uses jobs template files in priority order:
- %inputpath%\vd-deshake-%ext%-%int%.jobs.sample
- %inputpath%\vd-deshake-%ext%.jobs.sample
- templates\vd-deshake-%ext%-%int%.jobs.sample
- templates\vd-deshake-%ext%.jobs.sample
- templates\vd-deshake-default.jobs.sample
If templates directory is missing, it will be initialized from embedded template files.
See virtualdub documentation for jobs file format, and deshaker documentation for deshaker parameters.

Creates %inputpath%\%filename%.ds.log file
Runs "...\VirtualDub\Veedub64.exe" /s %filename%.ds.jobs /x
Returns only when finished
Default removes all temp files created.

If you close the terminal window before the end of processing all files, the ongoing processes will 
continue and close when completed, but no more new process will start.
If you close manually the ongoing processes, the result may be some damaged output file.

## Options ## 

-t	do not delete temp files (default will be deleted after the last file completed)
-o	overwrite existing files (default skip)
-p <#>	number of paralel processes (default 4)
-s <index> <value>	user settings of plugin. See doc at http://www.guthspot.se/video/deshaker.htm

## Bugs ##
- avi does not work
- PAL Wide is converting to 4:3

## External references ##
- [[http://virtualdub.org/]]
- [[http://ffmpeg.org/]]
- [[http://www.virtualdub.org/docs/vdscript.txt]]
- [[http://www.guthspot.se/video/deshaker.htm]]
- [[http://forum.videohelp.com/threads/367446-Virtualdub-External-Encoder-feature]]
