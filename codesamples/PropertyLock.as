package com.m.pyramid.components.Security
{


	import flash.events.Event;
	import flash.events.EventDispatcher;

	import mx.events.PropertyChangeEvent;

	public class PropertyLock
	{
		static public const LEVEL1_SECURITY:int = int.MAX_VALUE;
		static public const LEVEL2_SERVICE:int = int.MAX_VALUE - 1;
		static public const LEVEL3_UI:int = int.MAX_VALUE - 2;
		static public const LEVEL4_DATA:int = int.MAX_VALUE - 3;
		static public const LEVEL5_USER:int = int.MAX_VALUE - 4;

		public static function CreateSecurityLock(target:EventDispatcher, properties:Array):PropertyLock
		{
			return new PropertyLock(target,properties,true, LEVEL1_SECURITY);
		}

		public static function CreateServiceLock(target:EventDispatcher, properties:Array):PropertyLock
		{
			return new PropertyLock(target,properties,true,LEVEL2_SERVICE);
		}

		public static function CreateUILock(target:EventDispatcher, properties:Array):PropertyLock
		{
			return new PropertyLock(target,properties,true,LEVEL3_UI);
		}

		public static function CreateDataLock(target:EventDispatcher, properties:Array):PropertyLock
		{
			return new PropertyLock(target,properties,true,LEVEL4_DATA);
		}

		public static function CreateUserLock(target:EventDispatcher, properties:Array):PropertyLock
		{
			return new PropertyLock(target,properties,true,LEVEL5_USER);
		}

		private var _locked:Boolean;
		public var _target:EventDispatcher;
		private var _properties:Object;
		private var _locklevel:int;
		private var thisLockSettingProperty:Boolean = false;
		private var thisLockSettingPCEProperty:Boolean = false;

		public function PropertyLock(target:EventDispatcher, LockableProperties:Array, placeLock:Boolean = false, lockLevel:int = int.MAX_VALUE - 4)
		{
			_target = target;
			_properties = new Object();
			_locklevel = lockLevel;

			for each(var property:LockableProperty in LockableProperties)
			{
				 addProperty(property);
			}
			isLocked = placeLock;
		}

		public function addProperty(property:LockableProperty):Boolean
		{
			if(!_target.hasOwnProperty(property.name))
			{
				//throw new Error("Object " + getQualifiedClassName(_target) + " does not have a property called " + property.name + ".");
				//SECURITY
			//	trace ("SECURITY :: Object " + getQualifiedClassName(_target) + " does not have a property called " + property.name + ".");

//				var er:String = "SECURITY :: Object " + getQualifiedClassName(_target) + " does not have a property called " + property.name + ".";
//				SecurityManager.securityErrorLogs.push(er);
				return false;
			}
			if(_properties.hasOwnProperty(property.name))
			{
				return false;
			}
			else
			{
				_properties[property.name] = property;
				return true;
			}
		}

		private function applyLock():void
		{
			for (var name:String in _properties)
			{
				var property:LockableProperty = _properties[name] as LockableProperty;
				property.underlyingValue = _target[property.name];

				// right here is where lock fires
				_target[property.name] = property.lockedValue;
			//	trace ("SECURITY :: PROP LOCK " + _target.toString() + " just had its " + property.name + " set to " + property.lockedValue );

				if(property.associatedEvents != null)
				{
					var events:Array = property.associatedEvents.split(",");
					if(property.eventHandlers == null)
					{
						property.eventHandlers = new Array();
					}

					for(var i:int=0; i<events.length; i++)
					{
						var event:String = events[i] as String;

						if(event != PropertyChangeEvent.PROPERTY_CHANGE)
						{
							var func:Function = function(changeEvent:Event):void
							{
								changeEvent.stopImmediatePropagation();
								changeEvent.stopPropagation();
								if ( ! thisLockSettingProperty )
								{
									property.underlyingValue = _target[property.name];
								}else {
									thisLockSettingProperty = false;
								}
								if(_target[property.name] != (_properties[property.name] as LockableProperty).lockedValue)
								{
									if(changeEvent.cancelable)
									{
										changeEvent.preventDefault();
									}
									else
									{
										thisLockSettingProperty = true;
										_target[property.name] = (_properties[property.name] as LockableProperty).lockedValue;
									}
								}
							};

							_target.addEventListener(event, func, false, _locklevel);
							property.eventHandlers.push({event:event, handler:func});
						}
					}
				}
			}

			_target.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, onPropertyChange, false, _locklevel);

			_locked = true;
		}

		private function applyUnlock():void
		{
			if(!_locked)
			{
				return;
			}

			_target.removeEventListener(PropertyChangeEvent.PROPERTY_CHANGE, onPropertyChange, false);

			for(var name:String in _properties)
			{
				var property:LockableProperty = _properties[name] as LockableProperty;

				while(property.eventHandlers.length > 0)
				{
					var handlerObject:Object = property.eventHandlers.pop();
					_target.removeEventListener(handlerObject.event, handlerObject.handler, false);
				}
				// right here is where lock unlocks
				if (property.unlockedValue != null)
				{
					_target[property.name] = property.unlockedValue;
				} else {
					_target[property.name] = property.underlyingValue;
				}
			}


			_locked = false;
		}

		private function onPropertyChange(event:PropertyChangeEvent):void
		{
			if(event.property == null)
			{
				return;
			}
			else if(!(event.property is String))
			{
				return;
			}
			else if(_properties[event.property as String] == null)
			{
				return;
			}

			event.stopImmediatePropagation();
			event.stopPropagation();

			if ( ! thisLockSettingPCEProperty )
			{
				_properties[event.property].underlyingValue = _target[event.property];
			} else {
				thisLockSettingPCEProperty = false;
			}

			if(_target[event.property] != _properties[event.property].lockedValue)
			{
				if(event.cancelable)
				{
					event.preventDefault();
				}
				else
				{
					thisLockSettingPCEProperty = true;
					_target[event.property] = _properties[event.property].lockedValue;
				}
			}
		}


		public function get isLocked():Boolean
		{
			return _locked;
		}

		public function set isLocked(value:Boolean):void
		{
			if(value)
				applyLock();
			else
				applyUnlock();
		}

		public function get isUnlocked():Boolean
		{
			return !_locked;
		}

		public function set isUnlocked(value:Boolean):void
		{
			if(value)
				applyUnlock();
			else
				applyLock();
		}
	}
}