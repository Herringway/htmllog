/++
 + Adds support for logging std.logger messages to HTML files.
 + Authors: Cameron "Herringway" Ross
 + Copyright: Copyright Cameron Ross 2016
 + License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 +/
module htmllog;
import std.algorithm : among;
import std.array;
import std.conv : to;
import std.experimental.logger;
import std.exception : assumeWontThrow;
import std.format : format, formattedWrite;
import std.range : put;
import std.stdio : File;
import std.traits : EnumMembers;
import std.typecons : tuple;
/++
 + Logs messages to a .html file. When viewed in a browser, it provides an
 + easily-searchable and filterable view of logged messages.
 +/
public class HTMLLogger : Logger {
	///File handle being written to.
	private File handle;

	/++
	 + Creates a new log file with the specified path and filename.
	 + Params:
	 +   logpath = Full path and filename for the log file
	 +   lv = Minimum message level to write to the log
	 +   defaultMinDisplayLevel = Minimum message level visible by default
	 +/
	this(string logpath, LogLevel lv = LogLevel.all, LogLevel defaultMinDisplayLevel = LogLevel.all) @safe {
		super(lv);
		handle.open(logpath, "w");
		init(defaultMinDisplayLevel);
	}
	/++
	 + Writes a log file using an already-opened handle. Note that having
	 + pre-existing data in the file will likely cause display errors.
	 + Params:
	 +   file = Prepared file handle to write log to
	 +   lv = Minimum message level to write to the log
	 +   defaultMinDisplayLevel = Minimum message level visible by default
	 +/
	this(File file, LogLevel lv = LogLevel.all, LogLevel defaultMinDisplayLevel = LogLevel.all) @safe {
		super(lv);
		handle = file;
		init(defaultMinDisplayLevel);
	}
	~this() @safe {
		if (handle.isOpen) {
			writeFmt(HTMLTemplate.footer);
			handle.close();
		}
	}
	/++
	 + Writes a log message. For internal use by std.experimental.logger.
	 + Params:
	 +   payLoad = Data for the log entry being written
	 + See_Also: $(LINK https://dlang.org/library/std/experimental/logger.html)
	 +/
	override public void writeLogMsg(ref LogEntry payLoad) @safe {
		if (payLoad.logLevel >= logLevel)
			writeFmt(HTMLTemplate.entry, payLoad.logLevel, payLoad.timestamp.toISOExtString(), payLoad.timestamp.toSimpleString(), payLoad.moduleName, payLoad.line, payLoad.threadId, HtmlEscaper(payLoad.msg));
	}
	/++
	 + Initializes log file by writing header tags, etc.
	 + Params:
	 +   minDisplayLevel = Minimum message level visible by default
	 +/
	private void init(LogLevel minDisplayLevel) @safe {
		static bool initialized = false;
		if (initialized)
			return;
		writeFmt(HTMLTemplate.header, minDisplayLevel.among!(EnumMembers!LogLevel)-1);
		initialized = true;
	}
	/++
	 + Safe wrapper around handle.lockingTextWriter().
	 + Params:
	 +   fmt = Format of string to write
	 +   args = Values to place into formatted string
	 +/
	private void writeFmt(T...)(string fmt, T args) @trusted {
		formattedWrite(handle.lockingTextWriter(), fmt, args);
		handle.flush();
	}
}
///
@safe unittest {
	auto logger = new HTMLLogger("test.html", LogLevel.trace);
	logger.fatalHandler = () {};
	foreach (i; 0..100) { //Log one hundred of each king of message
		logger.trace("Example - Trace");
		logger.info("Example - Info");
		logger.warning("Example - Warning");
		logger.error("Example - Error");
		logger.critical("Example - Critical");
		logger.fatal("Example - Fatal");
	}
}
/++
 + Escapes special HTML characters. Avoids allocating where possible.
 +/
private struct HtmlEscaper {
	///String to escape
	string data;
	/+
	 + Converts data to escaped HTML string. Outputs to an output range to avoid
	 + unnecessary allocation.
	 +/
	void toString(T)(T sink) const if (isOutputRange!(T, char)) {
		foreach (character; data) {
			switch (character) {
				default: sink.put(character); break;
				case 0: .. case 9:
				case 11: .. case 12:
				case 14: .. case 31:
					assumeWontThrow(formattedWrite(sink, "&#%d", character.to!uint));
					break;
				case '\n', '\r': sink("<br/>"); break;
				case '&': sink("&amp;"); break;
				case '<': sink("&lt;"); break;
				case '>': sink("&gt;"); break;
			}
		}
	}
}
//
@safe pure unittest {
	import std.conv : text;
	assert(HtmlEscaper("").text == "");
	assert(HtmlEscaper("\n").text == "<br/>");
	assert(HtmlEscaper("\x1E").text == "&#30");
}
///Template components for log file
private enum HTMLTemplate = tuple!("header", "entry", "footer")(
`<!DOCTYPE html>
<html>
	<head>
		<title>HTML Log</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<style content="text/css">
			.trace        { color: lightgray; }
			.info         { color: black; }
			.warning      { color: darkorange; }
			.error        { color: darkred; }
			.critical     { color: crimson; }
			.fatal        { color: red; }

			body          { font-size: 10pt; margin: 0px; }
			.logmessage   { font-family: monospace; margin-left: 10pt; margin-right: 10pt; }
			.log          { margin-top: 15pt; margin-bottom: 15pt; }

			time, div.time {
				display: inline-block;
				width: 180pt;
			}
			div.source {
				display: inline-block;
				width: 200pt;
			}
			div.threadName {
				display: inline-block;
				width: 100pt;
			}
			div.message {
				display: inline-block;
				width: calc(100%% - 500pt);
			}
			header, footer {
				position: fixed;
				width: 100%%;
				height: 15pt;
				z-index: 1;
			}
			footer {
				bottom: 0px;
				background-color: lightgray;
			}
			header {
				top: 0px;
				background-color: white;
			}
		</style>
		<script language="JavaScript">
			function updateLevels(i){
				var style = document.styleSheets[0].cssRules[i].style;
				if (event.target.checked)
					style.display = "";
				else
					style.display = "none";
			}
		</script>
	</head>
	<body>
		<header class="logmessage">
			<div class="time">Time</div>
			<div class="source">Source</div>
			<div class="threadName">Thread</div>
			<div class="message">Message</div>
		</header>
		<footer>
			<form class="menubar">
				<input type="checkbox" id="level0" onChange="updateLevels(0)" checked> <label for="level0">Trace</label>
				<input type="checkbox" id="level1" onChange="updateLevels(1)" checked> <label for="level1">Info</label>
				<input type="checkbox" id="level2" onChange="updateLevels(2)" checked> <label for="level2">Warning</label>
				<input type="checkbox" id="level3" onChange="updateLevels(3)" checked> <label for="level3">Error</label>
				<input type="checkbox" id="level4" onChange="updateLevels(4)" checked> <label for="level4">Critical</label>
				<input type="checkbox" id="level5" onChange="updateLevels(5)" checked> <label for="level5">Fatal</label>
			</form>
		</footer>
		<script language="JavaScript">
			for (var i = 0; i < %s; i++) {
				document.styleSheets[0].cssRules[i].style.display = "none";
				document.getElementById("level" + i).checked = false;
			}
		</script>
		<div class="log">`,
`
			<div class="%s logmessage">
				<time datetime="%s">%s</time>
				<div class="source">%s:%s</div>
				<div class="threadName">%s</div>
				<div class="message">%s</div>
			</div>`,
`
		</div>
	</body>
</html>`);