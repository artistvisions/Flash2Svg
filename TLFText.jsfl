(function(dx){
	function ExtensibleTLFText(text,options){
		dx.Element.apply(this,arguments);
		return this;
	}
	ExtensibleText.prototype={
		__proto__:dx.Element.prototype,
		type:ExtensibleTLFText
	}
	dx.extend({TLFText:ExtensibleTLFText});
})(dx);
