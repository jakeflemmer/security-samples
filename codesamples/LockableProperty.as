package com.m.pyramid.components.Security
{
	public class LockableProperty
	{
		public var name:String;
		public var lockedValue:Object;
		public var associatedEvents:String;
		public var eventHandlers:Array;
		private var _underlyingValue:Object;
		private var _unlockedValue:Object;

		public function LockableProperty(propertyName:String, propertyValueWhenLocked:Object,
					commaSeperatedListOfEvents:String = null,propertyValueWhenUnlocked:Object=null)
		{
			name = propertyName;
			lockedValue = propertyValueWhenLocked;
			_unlockedValue = propertyValueWhenUnlocked;
			associatedEvents = commaSeperatedListOfEvents;
			trace("b");
		}

		public function get unlockedValue():Object{
			return _unlockedValue;
		}

		public function set unlockedValue(val:Object):void{
			_unlockedValue = val;
		}

		public function get underlyingValue():Object{
			return _underlyingValue;
		}

		public function set underlyingValue(val:Object):void{
			_underlyingValue = val;
		}

	}
}