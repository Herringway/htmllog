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

class HTMLLogger : Logger {
	File handle;

	this(string logpath, LogLevel lv = LogLevel.all, LogLevel defaultMinDisplayLevel = LogLevel.all) @safe {
		super(lv);
		handle.open(logpath, "w");
		init(defaultMinDisplayLevel);
	}
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
	override public void writeLogMsg(ref LogEntry payLoad) @safe {
		if (payLoad.logLevel >= logLevel)
			writeFmt(HTMLTemplate.entry, payLoad.logLevel, payLoad.timestamp.toISOExtString(), payLoad.timestamp.toSimpleString(), payLoad.moduleName, payLoad.line, payLoad.threadId, HtmlEscaper(payLoad.msg));
	}
	private void init(LogLevel minDisplayLevel) @safe {
		static bool initialized = false;
		if (initialized)
			return;
		writeFmt(HTMLTemplate.header, minDisplayLevel.among!(EnumMembers!LogLevel)-1);
		initialized = true;
	}
	private void writeFmt(T...)(string fmt, T args) @trusted {
		formattedWrite(handle.lockingTextWriter(), fmt, args);
		handle.flush();
	}
}
@safe unittest {
	auto logger = new HTMLLogger("test.html", LogLevel.trace);
	logger.fatalHandler = () {};
	foreach (i; 0..100) {
		logger.trace("Example - Trace");
		logger.info("Example - Info");
		logger.warning("Example - Warning");
		logger.error("Example - Error");
		logger.critical("Example - Critical");
		logger.fatal("Example - Fatal");
	}
}
private struct HtmlEscaper {
	string data;
	void toString(T)(T sink) const {
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
			for (var i = 0; i < 1; i++) {
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