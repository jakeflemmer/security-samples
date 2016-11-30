package com.m.pyramid.profile
{
	import com.m.pyramid.model.ReferenceObject;

	import mx.collections.ArrayCollection;

	public class StateSectorWrapper
	{
		// these are here because curiously Flex requires that comboBoxes in a dataGridColumn have a dataField property
  		// on the dataProvider even if the dataProviders are different for the dataGrid and the comboBox inside the dataGrid
  		public var label:String = "";
  		public var name:String = "";

		[Bindable]
		public var theSSLI:ArrayCollection;

		[Bindable]
		public var state:ReferenceObject;

		public function StateSectorWrapper()
		{
			theSSLI = new ArrayCollection();
			state = new ReferenceObject();
		}

	}
}