package com.m.pyramid.profile
{

	import com.m.pyramid.model.Role;
	import com.m.pyramid.model.UserProfile;
	import com.m.pyramid.model.helpers.UserProfileSearchCriteria;

	import flash.events.Event;

	public class UserProfileEvent extends Event
	{
		public static const FIND_EMPLOYEE_EVENT:String = "findEmployeeEvent";
		public static const SAVE_USER_PROFILE_EVENT:String = "saveUserProfileEvent";
		public static const SAVE_USER_ROLE_EVENT:String = "saveUserRoleEvent";
		public static const GET_ALL_PERMISSIONS_EVENT:String = "getAllPermissionsEvent";
		public static const GET_ALL_ROLES_EVENT:String = "getAllRolesEvent";
		public static const GET_USER_PROFILE_EVENT:String = "viewUserProfileEvent";
		public static const DELETE_ROLE_EVENT:String = "deleteRoleEvent";
		public static const OPEN_TEAM_HISTORY : String = "openTeamHistory";
		public static const CLOSE_POPUP : String = "closePopup";
		public static const NEW_VIEW_MODEL : String = "newViewModel";

		public var employeeSearchCriteria:UserProfileSearchCriteria;
		public var userRole:Role;
		public var userProfile:UserProfile;
		public var teamHistoryInfo:Object;

		public function UserProfileEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}

	}
}