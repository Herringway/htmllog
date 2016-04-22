module htmllog;
import std.experimental.logger;
import std.typecons : tuple;

class HTMLLogger : Logger {
	private import std.stdio : File;
	File handle;

	this(string logpath, LogLevel lv) {
		super(lv);
		handle = File(logpath, "w");
	}
	~this() {
		if (handle.isOpen) {
			handle.write(HTMLTemplate.footer);
			handle.flush();
			handle.close();
		}
	}
	void init() @trusted {
		import std.conv : to;
		import std.algorithm : among;
		import std.traits : EnumMembers;
		static bool initialized = false;
		if (initialized)
			return;
		handle.writef(HTMLTemplate.header, logLevel.among!(EnumMembers!LogLevel));
		initialized = true;
	}
	override void writeLogMsg(ref LogEntry payLoad) @trusted {
		import std.string : format;
		import std.array;
		init();
		handle.writefln(HTMLTemplate.entry, payLoad.logLevel, payLoad.timestamp.toISOExtString(), payLoad.timestamp.toSimpleString(), payLoad.moduleName, payLoad.threadId, htmlEscape(payLoad.msg).replace("\n", "<br />"));
		handle.flush();
	}
}
private char[] htmlEscape(inout(char[]) text) @trusted nothrow {
	import std.string : format;
	import std.array : appender;
	auto output = appender!(char[])();
	foreach (character; text) {
		switch (character) {
			default: output ~= character; break;
			case 0: .. case 9:
			case 11: .. case 13:
			case 14: .. case 31:
				try {
					output ~= format("&#%d", cast(uint)character);
				} catch (Exception) {}
				break;
			case '&': output ~= "&amp;"; break;
			case '<': output ~= "&lt;"; break;
			case '>': output ~= "&gt;"; break;
		}
	}
	return output.data;
}
enum HTMLTemplate = tuple!("header", "footer", "entry")(
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
`		</div>
	</body>
</html>`,
`		<div class="%s"><time datetime="%s">%s</time><div class="source">%s</div><div class="threadName">%s</div><div class="message">%s</div></div>`);