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

	this(string logpath, LogLevel lv = LogLevel.all) @safe {
		super(lv);
		handle.open(logpath, "w");
		init();
	}
	this(File file, LogLevel lv = LogLevel.all) @safe {
		super(lv);
		handle = file;
		init();
	}
	~this() @safe {
		if (handle.isOpen) {
			writeFmt(HTMLTemplate.footer);
			handle.close();
		}
	}
	void init() @safe {
		static bool initialized = false;
		if (initialized)
			return;
		writeFmt(HTMLTemplate.header, logLevel.among!(EnumMembers!LogLevel)-1);
		initialized = true;
	}
	override void writeLogMsg(ref LogEntry payLoad) @safe {
		writeFmt(HTMLTemplate.entry, payLoad.logLevel, payLoad.timestamp.toISOExtString(), payLoad.timestamp.toSimpleString(), payLoad.moduleName, payLoad.line, payLoad.threadId, HtmlEscaper(payLoad.msg));
	}
	void writeFmt(T...)(string fmt, T args) @trusted {
		formattedWrite(handle.lockingTextWriter(), fmt, args);
		handle.flush();
	}
}
struct HtmlEscaper {
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
`<html>
	<head>
		<title>HTML Log</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<style content="text/css">
			.trace        { position: relative; color: lightgray; display: none; }
			.info         { position: relative; color: black; }
			.warning      { position: relative; color: darkorange; }
			.error        { position: relative; color: darkred; }
			.critical     { position: relative; color: crimson; }
			.fatal        { position: relative; color: red; }
			body          { font-family: monospace; font-size: 10pt; margin: 0px; }

			.log          { margin: 0px 10pt 36px 10pt; }

			time, div.time {
				display: inline-block;
				vertical-align: top;
				width: 180pt;
			}
			div.source {
				display: inline-block;
				vertical-align: top;
				width: 200pt;
			}
			div.threadName {
				display: inline-block;
				vertical-align: top;
				width: 100pt;
			}
			div.message {
				width: calc(100%% - 480pt);
				display: inline-block;
			}
			form.menubar {
				position: fixed;
				bottom: 0px;
				padding: 4pt;
				width: 100%%;
				background-color: lightgray;
				z-index: 1;
				margin: 0px;
			}
		</style>
		<script language="JavaScript">
			function init() {
				populateLevels();
				updateLevels();
			}
			function populateLevels() {
				var sel = document.getElementById("Level");
				var matches = [];
				for (var i = 0; i < document.styleSheets[0].cssRules.length; i++) {
					if (document.styleSheets[0].cssRules[i].selectorText == "body")
						break;
					matches.push(document.styleSheets[0].cssRules[i].selectorText.charAt(1).toUpperCase() + document.styleSheets[0].cssRules[i].selectorText.substring(2));
				}
 				for (var i = 0; i < matches.length; i++) {
 					var option = document.createElement("option");
 					option.textContent = matches[i];
 					option.value = i;
 					sel.appendChild(option);
 				}
 				sel.selectedIndex = %s;
			}
			window.onload = init;
			function enableStyle(i){
				var style = document.styleSheets[0].cssRules[i].style;
				style.display = "block";
			}

			function disableStyle(i){
				var style = document.styleSheets[0].cssRules[i].style;
				style.display = "none";
			}

			function updateLevels(){
				var sel = document.getElementById("Level");
				var level = sel.value;
				for( i = 0; i < level; i++ ) disableStyle(i);
				for( i = level; i < 5; i++ ) enableStyle(i);
			}
		</script>
	</head>
	<body>
		<form class="menubar">
			Minimum Log Level:
			<select id="Level" onChange="updateLevels()">
			</select>
		</form>
		<div class="log">
		<div style="position: relative;"><div class="time">Time</div><div class="source">Source</div><div class="threadName">Thread</div><div class="message">Message</div></div>`,
`		<div class="%s"><time datetime="%s">%s</time><div class="source">%s:%s</div><div class="threadName">%s</div><div class="message">%s</div></div>`,
`		</div>
	</body>
</html>`);