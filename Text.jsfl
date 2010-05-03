(function(dx){
	function ExtensibleText(text,options){
		dx.Element.apply(this,arguments);
		return this;
	}
	ExtensibleText.prototype={
		__proto__:dx.Element.prototype,
		type:ExtensibleText
	}
	dx.extend({Text:ExtensibleText});
})(dx);
