package{

	import adobe.utils.MMEndCommand;
	import adobe.utils.MMExecute;
	import flash.external.ExternalInterface;
	import flash.events.*;

	public class SettingsSaver extends EventDispatcher {

		// event
		public static const EVENT_STATE_CHANGED:String = "stateChanged";
		public static const EVENT_GROUPS_CHANGED:String = "groupsChanged";


		public static const STATE_UNLOADED:String = "unloaded";
		public static const STATE_LOADING:String = "loading";
		public static const STATE_LOADED:String = "loaded";
		public static const STATE_MODIFIED:String = "modified"; // not saved, exists on disk
		public static const STATE_UNSAVED:String = "unsaved";   // not saved, doesn't exist on disk
		public static const STATE_SAVING:String = "saving";



		public function get settingTitle():String{
			return _currentSettings.title;
		}

		public function get settingsGroups():Vector.<SettingGroup>{
			return _settingsGroups;
		}
		public function get state():String{
			return _state;
		}


		private var _currentSettings:SettingGroup;
		private var _settingsGroups:Vector.<SettingGroup>;
		private var _settingsDefs:Vector.<SettingDefinition>;

		private var _settingsFolder:String;
		private var _overwriteHandler:Function;
		private var _autoSave:Boolean;
		private var _documentSaveName:String;

		private var _state:String = STATE_UNLOADED;

		public function SettingsSaver(settingsFolder:String, autoSave:Boolean=false, overwriteHandler:Function=null, documentSaveName:String=null, swfPanelName:String=null){
			_currentSettings = new SettingGroup(null, true);
			_settingsDefs = new Vector.<SettingDefinition>();

			_settingsGroups = new Vector.<SettingGroup>();

			_documentSaveName = documentSaveName;

			_settingsFolder = settingsFolder;
			_overwriteHandler = overwriteHandler;
			_autoSave = autoSave;

			if(MMExecute('FLfile.exists("'+settingsFolder+'")')!=='false'){
				var files:Array=MMExecute('FLfile.listFolder("'+settingsFolder+'","files")').split(',');
				for(var n=0;n<files.length;n++){
					var file:String = files[n];
					if(!file.length)break;

					var fileData = MMExecute('FLfile.read("'+settingsFolder+file+'")');
					if(fileData.length==0)continue;

					try{
						var xml:XML = new XML(fileData);
					}catch(e:Error){
						// bad settings file
						continue;
					}

					_settingsGroups.push(deserialise(xml));
				}
			}else{
				MMExecute('FLfile.createFolder("'+settingsFolder+'")')
			}

			if(_documentSaveName){
				if(!swfPanelName){
					throw new Error("swfPanelName must be provided to save settings to document");
				}
				// Document change...
				ExternalInterface.addCallback('documentChanged_'+documentSaveName,documentChanged);
				MMExecute([
					'fl.addEventListener(',
					'	"documentChanged",',
					'	function(){',
					'		extensible.swfPanel("'+swfPanelName+'").call("documentChanged_'+documentSaveName+'");',
					'	}',
					');'
				].join('\n'));

				//documentChanged();
			}

		}
		public function init():void{
			// Should be called after all settings are added

			if(_documentSaveName){
				doDocumentChanged();
			}
		}

		private function documentChanged():void{
			DelayedCall.call(doDocumentChanged, 0.1); // flash calls the handler multiple times, this will collate them
		}

		public function doDocumentChanged():void{
			if(MMExecute('extensible.doc')!='null' &&
				MMExecute('extensible.doc.documentHasData("'+_documentSaveName+'")')=='true'
			){
				var xml=new XML(MMExecute('extensible.doc.getDataFromDocument("'+_documentSaveName+'")'));
				updateSettingGroup(_currentSettings, deserialise(xml), true);
			}
		}

		public function setToFirst(allowUserCreated:Boolean):void{
			var group:SettingGroup;
			if(allowUserCreated){
				group = _settingsGroups[0];
			}else{
				for each(var g:SettingGroup in _settingsGroups){
					if(!g.userCreated){
						group = g;
						break;
					}
				}
			}
			if(group)setSettingTitle(group.title, true);
		}

		public function getXml():XML{
			return serialise(_currentSettings);
		}

		private function deserialise(xml:XML):SettingGroup{
			var ret = new SettingGroup(xml.@title, xml.@userCreated=='true');
			for each(var child in xml.children()){
				var value:* = child.text();
				if(value=="false"){
					value = false;
				}else if(value=="true"){
					value = true;
				}else if(value==parseFloat(value).toString()){
					value = parseFloat(value);
				}
				ret.setSetting(child.name(), value);
			}
			return ret;
		}

		private function serialise(group:SettingGroup, includeNonFile:Boolean=true):XML{
			var ret:XML = new XML("<settings></settings>");
			ret.@title = group.title;
			ret.@userCreated = group.userCreated;
			for each(var settingDef:SettingDefinition in _settingsDefs){
				var value = group.getSetting(settingDef.settingName);
				if(value!=null && (includeNonFile || settingDef.diskSave)){
					ret.appendChild(new XML("<"+settingDef.settingName+">"+value+"</"+settingDef.settingName+">"));
				}
			}
			return ret;
		}

		private function setState(state:String, overrideCheck:Boolean=false):void{
			if(!overrideCheck && _state==state)return;

			_state = state;
			dispatchEvent(new Event(EVENT_STATE_CHANGED));
		}
		public function setSettingTitle(title:String, loadSettings:Boolean):void{
			_currentSettings.title = title;
			var existing:SettingGroup;

			if(loadSettings && (existing = getSettingGroup(settingTitle))){
				updateSettingGroup(_currentSettings, existing, true);
				setState(STATE_LOADED, true);
			}else{
				checkState(true);
			}
		}

		private function areSame(group1:SettingGroup, group2:SettingGroup):Boolean{
			for each(var settingDef:SettingDefinition in _settingsDefs){
				if(group1.getSetting(settingDef.settingName)!=group2.getSetting(settingDef.settingName))return false;
			}
			return true;
		}

		public function addSetting(object:Object, prop:String, settingName:String, defValue:*, diskSave:Boolean=true, getter:Function=null, setter:Function=null, event:String=null):void{
			var setting:SettingDefinition = new SettingDefinition(object, prop, settingName, defValue, diskSave, getter, setter);
			_settingsDefs.push(setting);
			updateSetting(object, prop);

			if(event){
				(object as EventDispatcher).addEventListener( event, makeUpdateHandler(object, prop));
			}
		}

		public function updateSetting(object:Object, prop:String, doSave:Boolean=false):void{
			var def:SettingDefinition = getSettingDef(object, prop);
			var value:*;
			if(def.getter!=null){
				value = def.getter(object,prop);
			}else{
				value = object[prop];
			}
			
			_currentSettings.setSetting(def.settingName, value);
			checkState();

			DelayedCall.call(checkAutoSave, 0.5); // this collates rapid input (keystrokes, etc)
		}

		public function checkAutoSave():void{
			if(_state==STATE_UNSAVED || _state==STATE_MODIFIED){
				if(_autoSave){
					save();

				}
				if(_documentSaveName){

					MMExecute([
						'extensible.doc.addDataToDocument(',
						'	"'+_documentSaveName+'",',
						'	"string",',
						'	decodeURIComponent("'+encodeURIComponent(getXml().toXMLString())+'")',
						')'
					].join('\n'));
				}
			}
		}

		private function checkState(overrideCheck:Boolean=false):void{
			var existing:SettingGroup = getSettingGroup(settingTitle);
			if(!existing){
				setState(STATE_UNSAVED, overrideCheck);
			}else if(areSame(existing, _currentSettings)){
				setState(STATE_LOADED, overrideCheck);
			}else{
				setState(STATE_MODIFIED, overrideCheck);
			}
		}

		public function save():void{
			if(!settingTitle)return;

			if(_state==STATE_MODIFIED && _overwriteHandler!=null){
				_overwriteHandler(doSave);
			}else{
				doSave();
			}
		}

		private function doSave():void{

			var filePath:String = _settingsFolder+settingTitle+".xml";
			var xml:XML = serialise(_currentSettings, false);
			var output=(
				'decodeURIComponent("'+encodeURIComponent(filePath)+'"),'+
				'decodeURIComponent("'+encodeURIComponent(xml.toXMLString())+'")'
			);
			MMExecute('FLfile.write('+output+');');

			var existing:SettingGroup = getSettingGroup(settingTitle);
			if(!existing){
				existing = new SettingGroup(settingTitle, true);
				_settingsGroups.push(existing);
				dispatchEvent(new Event(EVENT_GROUPS_CHANGED));
			}
			updateSettingGroup(existing, _currentSettings, false);

			setState(STATE_LOADED);
		}

		private function updateSettingGroup(update:SettingGroup, withGroup:SettingGroup, updateObjects:Boolean):void{
			for each(var settingDef in _settingsDefs){
				var value:* = withGroup.getSetting(settingDef.settingName);
				if(value==null){
					value = settingDef.defValue;
				}

				update.setSetting(settingDef.settingName, value);
				if(updateObjects){

					if(settingDef.setter!=null){
						settingDef.setter(settingDef.object, settingDef.prop, value);
					}else{
						settingDef.object[settingDef.prop] = value;
					}
				}
			}
		}

		public function makeUpdateHandler(object:Object, prop:String):Function{
			var obj:Object = object;
			var p:String = prop;
			return function(e:Event):void{
				updateSetting(obj, p);
			}
		}

		public function remove():void{
			var filePath:String = _settingsFolder+settingTitle+".xml";
			MMExecute('FLfile.remove("'+filePath+'")');

			setState(STATE_UNSAVED);
			dispatchEvent(new Event(EVENT_GROUPS_CHANGED));
		}

		public function getSettingGroup(title:String):SettingGroup{
			for each(var group in _settingsGroups){
				if(group.title==title)return group;
			}
			return null;
		}

		private function getSettingDef(object:Object, prop:String):SettingDefinition{
			for each(var settingDef in _settingsDefs){
				if(settingDef.object==object && settingDef.prop==prop){
					return settingDef;
				}
			}
			return null;
		}
	}

}

class SettingDefinition{

	public var object:Object;
	public var prop:String;
	public var settingName:String;
	public var defValue:*;
	public var diskSave:Boolean;
	public var getter:Function;
	public var setter:Function;

	public function SettingDefinition(object:Object, prop:String, settingName:String, defValue:*, diskSave:Boolean, getter:Function, setter:Function){
		this.object = object;
		this.prop = prop;
		this.defValue = defValue;
		this.settingName = settingName;
		this.diskSave = diskSave;
		this.getter = getter;
		this.setter = setter;
	}
}