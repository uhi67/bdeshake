rem /* 
:: Batch deshaker
:: Author: Peter Uherkovich
:: Revision: 2017-05-16
:: See embedded documentation below
:: This batch file calls itself as jscript -- see js part below
:: This file contains embedded configutration template files at the end
@echo off
echo Batch deshaker v1.0
cscript //E:jscript %~dp0\%~nx0 %1 %2 %3 %4 %5 %6 %7 %8 %9
pause
exit
:: =================================================================================================
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

:: =================================================================================================
:: jscript part */ = 0;

/** Global settings */
// Set path of ffmpeg, eg. "c:\\progs\\Video Encoders\\FFmpeg\\64-bit"
var ffmpegbase = "c:\\progs\\Video Encoders\\FFmpeg\\64-bit";	// directory of "ffmpeg.exe" and "is-interlaced.js" filter script
var scriptdir = scriptdir = WScript.ScriptFullName.substring(0,WScript.ScriptFullName.lastIndexOf(WScript.ScriptName)-1);
var templatefolder = scriptdir + "\\templates"; // Set to empty to disable using template folder.
var commandbase = "c:\\progs\\VirtualDub\\Veedub64.exe /s ";
var outputextension = 'mp4';
var ps = 4; // Number of paralel processes. (Eg. in a 12 core AMD system the best was 4)
var exts = ['avi', 'avi', 'm2t', 'mpg', 'mpeg', 'mp2', 'mp4', 'mts', 'mov'];
var ffmpeg = '"'+ffmpegbase+'\\ffmpeg.exe"' + ' -i %1 -filter:v idet -frames:v 100 -an -f rawvideo -y NUL ';

Array.prototype.indexOf = function(value) {
    for(var i=0;i<this.length;i++) {
        if(this[i]==value) return i;
    }
    return -1;
};

// Default values
var fdeltemp = 1;
var foverwrite = 0;
var fdebug = 0;

// Global objects and constants
var ForReading = 1;
var WshRunning = 0; 
var fso = new ActiveXObject("Scripting.FileSystemObject");
var WshShell = new ActiveXObject("WScript.Shell");

// Statistics
var num = 0;				// Number of processed files so far
var sum = 0;				// kbyte/s (avg = sum/num)
var numfiles = 1; 			// Number of files (including skipped ones)
var sumfiles = 0; 			// Sum of sizes of all files to process
var ready = 0;				// Processed bytes so far
var lastsum = new Date();	// Last time of summary
var starttime = lastsum; 
var existingfile = 0;		// Files ready

// Determine input file
if(WScript.Arguments.length<1) {
	Console.ForegroundColor(1);
	WScript.Echo("Using:");
	WScript.Echo("---------------------------------------");
	WScript.Echo(" Drop file or directory to this script");
	WScript.Echo("---------------------------------------");
	WScript.Echo("Deshakes one file to the same directory with .ds.mp4 name extension if not exists");
	WScript.Echo("Skips existing output files, unless -o switch specified");
	WScript.Echo("creates %filename%.ds.jobs temp file");
	WScript.Echo("uses vd-deshake-%ext%.jobs.sample file");
	WScript.Echo("uses vd-deshake-%ext%.vdscript file for deshaker parameters if exists");
	WScript.Echo("creates private %filename%.ds.log file");
	WScript.Echo("runs 'c:\progs\VirtualDub\Veedub64.exe' /s %filename%.ds.jobs /x");
	WScript.Echo("returns only when finished");
	WScript.Echo(" removes temp files");
	WScript.Echo(" -t	do not delete temp files");
	WScript.Echo(" -o	overwrite existing files");
	WScript.Echo(" -p <#>	number of paralel processes (default 4)");
	WScript.Echo(" -d 	show debug info");
	WScript.Echo(" -s <index>=<value>,...	user settings of plugin. See doc at http://www.guthspot.se/video/deshaker.htm");
	WScript.Quit(1);
}

var filename = WScript.Arguments.Item(0);
/** {array} Array of user settings [index, value] elements */
var user_settings = [];

// Determine options
for(var i=1;i<WScript.Arguments.length;i++) {
	if(WScript.Arguments.Item(i)=='-t') fdeltemp = 0;
	if(WScript.Arguments.Item(i)=='-o') foverwrite = 1;
	if(WScript.Arguments.Item(i)=='-d') fdebug = 1;
	if(WScript.Arguments.Item(i)=='-p') {
		if(++i >= WScript.Arguments.length) break;
		ps = parseInt(WScript.Arguments.Item(i));
	}
	if(WScript.Arguments.Item(i)=='-s') {
		if(++i >= WScript.Arguments.length) break;
		var values = parseInt(WScript.Arguments.Item(i));
		var valuelist = values.split(',');
		for(var j=0;j<valuelist.length;j++) {
			var iv = valuelist[j].split('=');
			user_settings.push([iv[0], iv[1]]);
		}
	}
}

if(fdebug && templatefolder!='') WScript.Echo("Using template directory " + templatefolder);

// Check and initialize template directory
if(templatefolder!='' && !fso.FolderExists(templatefolder)) {
	if(!fso.FolderExists(fso.getParentFolderName(templatefolder))) {
		WScript.Echo("Configuration error: Invalid templatefolder: parent does not exists: "+templatefolder);
		WScript.Quit(4);
	}
	var tf = fso.CreateFolder(templatefolder);
	// initialize with embedded files
	var scriptfile = fso.GetFile(filename);
    var ts = scriptfile.OpenAsTextStream(ForReading);
	// TODO: ...
}

// Detect directory
if(fso.FolderExists(filename)) {
	WScript.Echo(filename + " is a folder.");
    var folderspec = filename;
    var folder = fso.GetFolder(folderspec);
    var fc = new Enumerator(folder.files);
    
    // fájlok mennyiségének meghatározása
    for(;!fc.atEnd(); fc.moveNext()) {
    	var filename1 = fc.item().Name;
        var ext = fso.GetExtensionName(filename1).toLowerCase();
        // Skipping unsupported extensions
        if(exts.indexOf(ext)==-1) continue;
        // Skipping deshaked files
        if(filename1.indexOf('.ds.')!=-1) continue;
        // Skipping existing
        var path1 = folderspec+'\\'+filename1;
        var filename2 = path1 + '.ds.'+outputextension;
    	if(fso.FileExists(filename2) && !foverwrite) {
    		existingfile++;
    		continue;
   		}

        numfiles++;
        sumfiles += fso.GetFile(folderspec+'\\'+filename1).size;
        lastsum = new Date();
    }
    WScript.Echo("Number of files: "+numfiles+", "+Math.floor(sumfiles/1000)+" kbytes.");
    WScript.Echo("Number of ready files: "+existingfile+".");
    
	// File processing loop
    fc.moveFirst();
    var processes = new Array(ps); // [[ps,name,start,size],...] 
    for(;!fc.atEnd(); fc.moveNext()) {
    	var filename1 = fc.item().Name;
        var ext = fso.GetExtensionName(filename1).toLowerCase();
        // Skipping unsupported extensions
        if(exts.indexOf(ext)==-1) continue;
        // Skipping deshaked files
        if(filename1.indexOf('.ds.')!=-1) continue;
        var path1 = folderspec+'\\'+filename1;
        // Skipping existing
        var path1 = folderspec+'\\'+filename1;
        var filename2 = path1 + '.ds.'+outputextension;
    	if(fso.FileExists(filename2) && !foverwrite) continue;
        // Waiting for empty slot
        var p = waitForFree(processes);
        var oExec = deshake_file(path1, templatefolder, fdeltemp, foverwrite);
        if(oExec) {
	        var px = []; 
	        px[0] = oExec;
	        px[1] = filename1;
	        px[2] = new Date();
	        px[3] = fso.GetFile(path1).size;
	        processes[p] = px;
        }
        showStatus(processes);
    }
    // Waiting for finish all process
    waitForFinish(processes);
	showStatus(processes);
    if(fdebug) WScript.Echo("Folder process completed.\n");
	WScript.Quit(0);
} 

// Detect one file
if(!fso.FileExists(filename)) {
	WScript.Echo("Input file " + filename + " does not exist, skipping.");
	WScript.Quit(1);
}

var oExec = deshake_file(filename, templatefolder, fdeltemp, foverwrite);

// wait for complete
if(oExec) while(oExec.Status == WshRunning) WScript.Sleep(100);
WScript.Echo("File "+filename+" finished.");
// delete temp files
if(fdeltemp) {
    var logfilename = filename + '.ds.log';
    var jobfilename = filename + ".ds.jobs";
    if(fdebug) WScript.Echo("Delete temp files (.log, .jobs)");
    fso.DeleteFile(logfilename);
    fso.DeleteFile(jobfilename);
}
WScript.Quit(0);

/**
 * Reports progress on terminal
 * @param {array} processes
 */
function showStatus(processes) {
    if(numRun(processes)>0) {
	    WScript.Echo("\nCurrently running:");
	    for(var i=0;i<processes.length;i++) {
	        px = processes[i];
	        if(px) {
		        var now = new Date();
		        var elapsed = ((now - px[2]) + 1)/1000; // s
		        if(px) {
		        	var sz = Math.floor(parseInt(px[3])/1000)/1000;	// Mbyte
		        	var es = num ? (sz*1000) / (sum/num/1000) : sz/0.045; 		// Estimated time from avg, s
		        	var pc = num ? Math.floor((elapsed / es) * 100) : '('+Math.floor((elapsed / es) * 100)+')';	// percent ready
				    WScript.Echo('- ' + px[0].status +': ' + px[1]+ ' \t ' + Math.floor(elapsed) + "s \t" + sz.toString().lPad(9) + " Mbytes, \t" + pc + '%');
		        }
	     	}
	 	}
	}
    var now = new Date();
    var elapsedall = ((now - starttime) + 1)/1000; // s
    var elapsed = ((now - lastsum) + 1)/1000; // s
    var speed = (Math.floor(sum/num)/1000*ps); // kbyte/s
	var ready1 = ready + (speed*elapsed*1000); // byte
	var pc = Math.floor(ready1 / sumfiles * 100); // %
	var estimated = Math.floor((sumfiles - ready1)/speed/1000); // s
	if(num) {
		WScript.Echo("Elapsed time since last file: "+Math.floor(elapsed)+"s. Overall time: "+Math.floor(elapsedall)+" s. ");
		WScript.Echo("Files completed: "+num+" of "+numfiles+" . Average speed: "+speed+" kbyte/s. Progress:"+pc+"% \n");
	    WScript.Echo("Processed data: "+Math.floor(ready/1000)+"+"+Math.floor(speed*elapsed)+" of "+Math.floor(sumfiles/1000)+" kbytes.");
		WScript.Echo("Estimated end time: "+Math.floor(estimated)+"s. ");
	}
	else WScript.Echo("");
}

/**
 * Returns first free index of processes array
 * If no any free element, waits for one
 * @param {array} processes
 * @returns {int}
 */
function waitForFree(processes) {
    var s = 0;
    while((f = firstFree(processes))==-1) {
        WScript.Sleep(100);
        if((s++ % 10)==0) WScript.StdOut.Write(".");
        if((s % 600)==0) {
        	showStatus(processes);
        }
    }
    return f;
}

/**
 * Waits for finishing all ongoing processes
 * @param {array} processes
 * @returns void
 */
function waitForFinish(processes) {
    var s = 0;
	while(numRun(processes)>0) {
		firstFree(processes);
        WScript.Sleep(100);
        if((s++ % 10)==0) WScript.StdOut.Write(".");
        if((s % 600)==0) {
        	showStatus(processes);
        }
	}
}

/**
 * Number of running processes
 * @param {array} processes
 * @returns {int}
 */
function numRun(processes) {
	var n = 0;
    for(var i=0;i<processes.length;i++) {
        p = processes[i] ? processes[i] : null;
        if(p===null) continue;
        if(p[0].Status == WshRunning) n++;
        else {
        	// Finished process must be reported and deleted
        	finishProcess(p);
            processes[i] = null;
        }
    }
    return n;
}

/**
 * Finds first epmty or stopped process in processes array.
 * Meanwhile, reports and deletes stopped processes.
 * @param {array} processes
 * @returns {int} -- The index of first free slot. Returns -1 if not found.
*/
function firstFree(processes) {
	var r = -1;
    for(var i=0;i<processes.length;i++) {
        p = processes[i] ? processes[i] : null;
        if(p===null) { if(r==-1) r = i; }
        else if(p[0].Status != WshRunning) {
        	finishProcess(p);
            processes[i] = null;
            if(r==-1) r = i;
        }
    }
    return r;
}

/**
 * Reports finishing of a process and collects statistics
 * @param {array} process: [0]=status, [1]=filename, [2]=start_time [3]=file_size
 */
function finishProcess(p) {
   	// Reports finishing of a process
    var now = new Date();
	var elapsed = ((now - p[2]) + 1)/1000; // s
	var speed = Math.floor(parseInt(p[3]) / elapsed); 	// Speed of closing file, byte/s
	var filename = p[1];
	WScript.Echo("\nFile " + filename + " has been finished in "+elapsed+" seconds ("+(speed/1000)+" kbyte/s)");
	
	// Collects statistics
	sum += speed;  			// Aggregated byte/s
	num++;					// Number of processed files
	ready += parseInt(p[3]); // Sum of processed bytes
    lastsum = now;
	
	// Deletes temp files
	if(fdeltemp) {
		var logfilename = filename + '.ds.log';
		var jobfilename = filename + ".ds.jobs";
		if(fdebug) WScript.Echo("Delete temp files "+jobfilename+". "+logfilename);
		fso.DeleteFile(logfilename);
		fso.DeleteFile(jobfilename);
	}
}

/**
 *  Deshakes a file
 *  Uses template file based on file extension, or the default.
 *	If none of above template file found, stops with error
 *
 *  @param {string} filename
 *  @param {string} templatefolder -- directory of template files (.jobs.sample)
 *  @param {int} fdeltemp -- 1=deletes temporary files
 *  @param {int} foverwrite -- 1=overwrites existing output files
 *  @return {int|null} -- process identifier or null if skipping file
 */
function deshake_file(filename, templatefolder, fdeltemp, foverwrite) {
    var ext = fso.GetExtensionName(filename).toLowerCase();
    var inputpath = fso.getParentFolderName(filename);
    WshShell.CurrentDirectory = inputpath;
    
    // Determine output file
    var filename2 = filename + '.ds.'+outputextension;
    if(fso.FileExists(filename2)) {
    	if(foverwrite) {
    		WScript.Echo("Output file " + filename2 + " exist, overwriting.");
    	}
    	else {
    		WScript.Echo("Output file " + filename2 + " exist, skipping.");
    		return null;
    	}
    }
    
    // Determines temporary filenames - Unique names are important due to paralel processing
    var logfilename = filename + '.ds.log';
    var jobfilename = filename.replace(/[\s]+/g, "_") + ".ds.jobs";

	// Determines interlace
	var com1 = ffmpeg.replace(/%1/g, filename);
	var oExec1 = WshShell.Exec(com1);
	while (oExec1.Status == 0) WScript.Sleep(100);
	var intl = is_interlaced(oExec1.stdErr);
    
    // determines template file
    var samplefilenames = [
    	inputpath + "\\vd-deshake-"+ext+"-"+intl+".jobs.sample",
    	inputpath + "\\vd-deshake-"+ext+".jobs.sample",
    	inputpath + "\\vd-deshake-"+intl+".jobs.sample",
    	inputpath + "\\vd-deshake-default.jobs.sample",
    	templatefolder + "\\vd-deshake-"+ext+"-"+intl+".jobs.sample",
    	templatefolder + "\\vd-deshake-"+ext+".jobs.sample",
    	templatefolder + "\\vd-deshake-"+intl+".jobs.sample",
    	templatefolder + "\\vd-deshake-default.jobs.sample"
	];
	for(var i=0;i<samplefilenames.length;i++) {
	    var samplefilename = samplefilenames[i];	
	    if(fso.FileExists(samplefilename)) break;
	}
    if(!fso.FileExists(samplefilename)) {
    	WScript.Echo("Sample file " + samplefilename + " does not exist. ("+ext+","+intl+")");
    	WScript.Quit(3);
    }
    if(fdebug) WScript.Echo("Using samplefile " + samplefilename);

    // Creates jobfile from sample file
    var samplefile = fso.GetFile(samplefilename);
    var ts = samplefile.OpenAsTextStream(ForReading);
    var sample = ts.ReadAll().split("\n");	// sorok tömbje
    var jobfile = fso.CreateTextFile(jobfilename, true);
    var filename0 = fso.GetFileName(filename).replace(/[\s]+/g, "_");              // Filename withouth path
    var filename1x = filename.replace(/\\/g, "\\\\");
    var filename2x = filename2.replace(/\\/g, "\\\\");
	for(var i=0;i<sample.length;i++) {
		
		sample[i] = sample[i].replace(/%filename1%/gi, filename).replace(/%filename2%/gi, filename2).replace(/%filename1x%/gi, filename1x).replace(/%filename0%/gi, filename0);
		// User settings
		// Updates script lines like: VirtualDub.video.filters.instance[xxx].Config("19|1|30|4|1|0|1|0|640|480|1|2|1500|2000|1000|2000|4|1|1|2|8|30|300|4|C:\\Users\\uhi\\AppData\\Local\\Deshaker\\Deshaker.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|15|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
		var settings_re = /VirtualDub\.video\.filters\.instance\[(\w+)\]\.Config\(\"([^"]+)\"\);/i;
		var settings_match = settings_re.exec(sample[i]);
		if(settings_match) {
			var pluginindex = settings_match[1];
			var settings = settings_match[2];
			if(fdebug) WScript.Echo("\nOriginal settings: " + settings+ "\n");
			sx = settings.split('|');
			if(user_settings.length) {
				for(var j=0;j<user_settings.length;j++) {
					sx[user_settings[j][0]-1] = user_settings[j][1];
				}
				settings = sx.join('|');
				if(fdebug) WScript.Echo("Modified settings: " + settings+ "\n");
				sample[i] = sample[i].replace(settings_re, 'VirtualDub.video.filters.instance[$1].Config("'+settings+'");');
			}
		}
	}
	job = sample.join("\n");
    jobfile.Write(job);
    jobfile.close();
    
    // Running job
    var command = commandbase + jobfilename +" /x";
    WScript.Echo("\nDeshaking file " + filename);
    if(fdebug) WScript.Echo(command);
    var oExec = WshShell.Exec(command);
    return oExec;    
}

/**
 * Determines interlace status of ffmpeg output
 * ffmpeg -i %1 -filter:v idet -frames:v 100 -an -f rawvideo -y NUL 2>&1 | cscript is-interlaced.js
 * 
 * @param {TextStream} strm -- output of ffmpeg 
 * @returns {string} -- bff/tff/pro/und
 */
function is_interlaced(strm) {
	var tff = 0;
	var bff = 0;
	var pro = 0;
	var und = 0;
	
	while (!strm.AtEndOfStream)
	{
		var str = strm.ReadLine();
		var mtff = str.match(/TFF:(\d+)\s/);
		if(mtff) tff += parseInt(mtff[1])
		var btff = str.match(/BFF:(\d+)\s/);
		if(btff) bff += parseInt(btff[1])
		var mpro = str.match(/Progressive:(\d+)\s/);
		if(mtff) pro += parseInt(mpro[1])
		var mund = str.match(/Undetermined:(\d+)\s/);
		if(mund) und += parseInt(mund[1])
	}
	
	if(tff>bff && tff>pro && tff>und) return('tff');
	else if(bff>pro && bff>und) return('bff');
	else if(pro>0 && pro>und) return('pro');
	return('und');
}

function String.prototype.lPad(len, chr) {
	if(!chr) chr=' ';
	var p = '';
	var l = len - this.length;
	for(var i=0;i<l;i++) p += chr;
	return p + this;
}

/* @data vd-deshake-default.jobs.sample EOF--
// VirtualDub script - deshaker - default
declare deshaker;
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|1|30|4|1|0|1|0|640|480|1|2|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|15|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.RunNullVideoPass();
VirtualDub.Close();
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetOutputFormat(7);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|2|30|4|1|0|1|0|640|480|1|2|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|15|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.ExportViaEncoderSet(U"%filename2%", "MP4 (video/audio)");
VirtualDub.Close();
EOF--*/

/* @data vd-deshake-mts.jobs.sample EOF--
// VirtualDub script - deshaker - mts
declare deshaker;
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
VirtualDub.video.filters.Add("deinterlace");
VirtualDub.video.filters.instance[0].Config(0,1,0);
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|1|30|4|1|0|1|0|640|480|0|1|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|5|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.RunNullVideoPass();
VirtualDub.Close();
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetOutputFormat(7);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
VirtualDub.video.filters.Add("deinterlace");
VirtualDub.video.filters.instance[0].Config(0,1,0);
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|2|30|4|1|0|1|0|640|480|0|1|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|5|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.ExportViaEncoderSet(U"%filename2%", "MP4 (video/audio)");
VirtualDub.Close();
EOF--*/

/* @data vd-deshake-mts-bff.jobs.sample EOF--
// VirtualDub script - deshaker - mts-bff
declare deshaker;
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
//VirtualDub.video.SetOutputFormat(7);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
VirtualDub.video.filters.Add("deinterlace");
VirtualDub.video.filters.instance[0].Config(0,0,0);
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|1|30|4|1|0|1|0|640|480|0|1|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|5|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.RunNullVideoPass();
VirtualDub.Close();
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetOutputFormat(7);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
VirtualDub.video.filters.Add("deinterlace");
VirtualDub.video.filters.instance[0].Config(0,0,0);
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|2|30|4|1|0|1|0|640|480|0|1|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|5|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.ExportViaEncoderSet(U"%filename2%", "MP4 (video/audio)");
VirtualDub.Close();
EOF--*/

/* @data vd-deshake-mts-pro.jobs.sample EOF--
// VirtualDub script - deshaker - mts-pro

declare deshaker;
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|1|30|4|1|0|1|0|640|480|0|1|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|5|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.RunNullVideoPass();
VirtualDub.Close();
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetOutputFormat(7);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|2|30|4|1|0|1|0|640|480|0|1|1500|2000|1000|2000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|1|200|200|100|100|0|0|0|0|0|0|0|1|25|25|5|5|1|1|30|30|0|50|0|0|1|1|1|10|1000|1|88|1|1|20|5000|80|20|0|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.ExportViaEncoderSet(U"%filename2%", "MP4 (video/audio)");
VirtualDub.Close();
EOF--*/

/* @data vd-deshake-mts-tff.jobs.sample EOF--
// VirtualDub script - deshaker - mts-tff
declare deshaker;
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|1|30|4|1|0|1|0|640|480|1|2|1500|2500|1000|1000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|0|100|100|40|80|0|0|0|0|0|1|1|1|15|20|5|5|1|1|10|10|0|15|0|0|1|1|1|10|1000|1|88|1|0|20|5000|100|20|1|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.RunNullVideoPass();
VirtualDub.Close();
VirtualDub.Open(U"%filename1%","",0);
VirtualDub.audio.SetSource(1);
VirtualDub.audio.SetMode(0);
VirtualDub.audio.SetInterleave(1,500,1,0,0);
VirtualDub.audio.SetClipMode(1,1);
VirtualDub.audio.SetEditMode(1);
VirtualDub.audio.SetConversion(0,0,0,0,0);
VirtualDub.audio.SetVolume();
VirtualDub.audio.SetCompression();
VirtualDub.audio.EnableFilterGraph(0);
VirtualDub.video.SetInputFormat(0);
VirtualDub.video.SetOutputFormat(7);
VirtualDub.video.SetMode(3);
VirtualDub.video.SetSmartRendering(0);
VirtualDub.video.SetPreserveEmptyFrames(0);
VirtualDub.video.SetFrameRate2(0,0,1);
VirtualDub.video.SetIVTC(0, 0, 0, 0);
VirtualDub.video.SetCompression();
VirtualDub.video.filters.Clear();
deshaker = VirtualDub.video.filters.Add("Deshaker v3.1");
VirtualDub.video.filters.instance[deshaker].Config("19|2|30|4|1|0|1|0|640|480|1|2|1500|2500|1000|1000|4|1|1|2|8|30|300|4|%filename0%.ds.log|0|0|100|100|40|80|0|0|0|0|0|1|1|1|15|20|5|5|1|1|10|10|0|15|0|0|1|1|1|10|1000|1|88|1|0|20|5000|100|20|1|0|ff00ff");
VirtualDub.audio.filters.Clear();
VirtualDub.subset.Delete();
VirtualDub.video.SetRange();
// -- $reloadstop --
VirtualDub.ExportViaEncoderSet(U"%filename2%", "MP4 (video/audio)");
VirtualDub.Close();
EOF--*/
