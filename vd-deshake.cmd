rem /* 
:: Batch deshaker
:: Author: Peter Uherkovich
:: Revision: 2017-05-16
:: See documentation below
:: This batch file calls itself as javascript -- see js part below
@echo off
echo Batch deshaker v1.0
cscript //E:jscript %~dp0\%~nx0 %1 %2 %3
pause
exit
:: =================================================================================================
# Batch deshaker #

Deshakes one file or files of a directory to the same directory with .ds.mp4 name extension

## Using ##

 vd-deshake.js filename [-t] [-o]

Skips existing output files, unless -o switch specified.
creates %filename%.ds.jobs temp file
Detect interlaced files into %int%
uses jobs template files in priority order:
- %inputpath%\vd-deshake-%ext%-%int%.jobs.sample
- %inputpath%\vd-deshake-%ext%.jobs.sample
- samples\vd-deshake-%ext%-%int%.jobs.sample
- samples\vd-deshake-%ext%.jobs.sample
- samples\vd-deshake-default.jobs.sample
Creates %inputpath%\%filename%.ds.log file
Runs "...\VirtualDub\Veedub64.exe" /s %filename%.ds.jobs /x
Returns only when finished
Default removes temp files created.

## Options ## 

-t	do not delete temp files (default delete at end)
-o	overwrite existing files (default skip)
-p <#>	number of paralel processes (default 4)
-s <index> <value>	user settings of plugin. See doc at http://www.guthspot.se/video/deshaker.htm

## Bugs ##
- avi does not work
- PAL Wide is converting to 4:3

:: =================================================================================================
:: Javascript part */ = 0;

// Global settings
// Set path of ffmpeg, eg. "c:\\progs\\Video Encoders\\FFmpeg\\64-bit"
var ffmpegbase = "c:\\progs\\Video Encoders\\FFmpeg\\64-bit";	// directory of "ffmpeg.exe" and "is-interlaced.js" filter script
var scriptdir = scriptdir = WScript.ScriptFullName.substring(0,WScript.ScriptFullName.lastIndexOf(WScript.ScriptName)-1);
var templatefolder = scriptdir + "\\templates";
var commandbase = scriptdir + "\\..\\Veedub64.exe /s ";
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

// Global objects and constants
var ForReading = 1;
var WshRunning = 0; 
var fso = new ActiveXObject("Scripting.FileSystemObject");
var WshShell = new ActiveXObject("WScript.Shell");

// Statistics
var num = 0;	// ténylegesen feldolgozott fájlok száma
var sum = 0;	// kbyte/s (avg = sum/num)
var numfiles = 1; // összes feldolgozandó fájlok száma (tehát nem számítva a bármilyen okból kihagyottakat))
var sumfiles = 0; // összes feldolgozandó fájlok összes mérete (byte) 
var ready = 0;		// feldolgozott bájtok száma
var lastsum = new Date(); // utolsó összegzés ideje
var starttime = lastsum; 
var existingfile = 0;	// Már kész fájl

// Determine input file
if(WScript.Arguments.length<1) {
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
	WScript.Echo(" -s <index> <value>	user settings of plugin. See doc at http://www.guthspot.se/video/deshaker.htm");
	WScript.Quit(1);
}

var filename = WScript.Arguments.Item(0);
var user_settings = [];

// Determine options
for(var i=1;i<WScript.Arguments.length;i++) {
	if(WScript.Arguments.Item(i)=='-t') fdeltemp = 0;
	if(WScript.Arguments.Item(i)=='-o') foverwrite = 1;
	if(WScript.Arguments.Item(i)=='-p') {
		if(++i >= WScript.Arguments.length) break;
		ps = parseInt(WScript.Arguments.Item(i));
	}
	if(WScript.Arguments.Item(i)=='-s') {
		if(++i >= WScript.Arguments.length) break;
		var index = parseInt(WScript.Arguments.Item(i));
		if(++i >= WScript.Arguments.length) break;
		var value = parseInt(WScript.Arguments.Item(i));
		user_settings.push([index, value]);
	}
}

WScript.Echo("Using template directory " + templatefolder);

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
    
	// Feldolgozási ciklus
    fc.moveFirst();
    var processes = new Array(ps); // [[ps,name,start],...] 
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
    WScript.Echo("Folder process completed.\n");
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
// TODO: delete temp files
if(fdeltemp) {
    var logfilename = filename + '.ds.log';
    var jobfilename = filename + ".ds.jobs";
    WScript.Echo("Delete temp files (.log, .jobs)");
    fso.DeleteFile(logfilename);
    fso.DeleteFile(jobfilename);
}


function showStatus(processes) {
    // Státuszjelentés
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

/*
 *  Visszaadja a process tömb első üres elemét.
 *  Ha nincs, vár egy processs befejezéséig
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

/*
 *  Vár az összes process befejezéséig
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

/*
 *	Futó processzek száma
 */
function numRun(processes) {
	var n = 0;
    for(var i=0;i<processes.length;i++) {
        p = processes[i] ? processes[i] : null;
        if(p===null) continue;
        if(p[0].Status == WshRunning) n++;
        else {
        	// Befejeződött processzt törölni és jelenteni kell
        	finishProcess(p);
            processes[i] = null;
        }
    }
    return n;
}

/*
 * Vissazadja a process tömb első üres vagy már nem futó indexét
 * Mindenképpen végigmegy a tömbön, és a közben leállt processzeket zárja.
 *  -1, ha nincs üres eleme
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

/*
 * Jelenti a processz befeződését és gyűjti a statisztikát
 */
function finishProcess(p) {
   	// Befejezés jelentés
    var now = new Date();
	var elapsed = ((now - p[2]) + 1)/1000; // s
	var speed = Math.floor(parseInt(p[3]) / elapsed); // záródó fájl sebessége, byte/s
	WScript.Echo("\nFile " + p[1]+ " has been finished in "+elapsed+" seconds ("+(speed/1000)+" kbyte/s)");
	
	// Statisztika gyűjtés
	sum += speed;  	// Aggregált byte/s
	num++;			// Feldolgozott fájlok száma
	ready += parseInt(p[3]); // Feldolgozott bytok száma
    lastsum = now;
}

/*
 *  Deshakes a file
 *  Uses template file based on file extension, or the default.
 *	If none of above template file found, stops with error
 *
 *  @param filename
 *  @param templatefolder -- directory of template files (.jobs.sample)
 *  @param fdeltemp -- 1=deletes temporary files
 *  @param foverwrite -- 1=overwrites existing output files
 *  @return process identifier or null
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
    WScript.Echo("Using samplefile " + samplefilename);

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
			WScript.Echo("\nOriginal settings: " + settings+ "\n");
			sx = settings.split('|');
			if(user_settings.length) {
				for(var j=0;j<user_settings.length;j++) {
					sx[user_settings[j][0]-1] = user_settings[j][1];
				}
				settings = sx.join('|');
				WScript.Echo("Modified settings: " + settings+ "\n");
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
    //WScript.Echo(command);
    var oExec = WshShell.Exec(command);
    return oExec;    
}

/*
 * Determines interlace status of ffmpeg output
 * ffmpeg -i %1 -filter:v idet -frames:v 100 -an -f rawvideo -y NUL 2>&1 | cscript is-interlaced.js
 * 
 * @param strm TextStream -- output of ffmpeg 
 * @returns string -- bff/tff/pro/und
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
