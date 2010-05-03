(function(dx){
	function ExtensibleShape(shape,options){
		dx.Element.apply(this,arguments);
		this.cache.cubicSegmentPoints=this.cache.cubicSegmentPoints||new dx.Array();
		return this;
	}
	ExtensibleShape.prototype={
		__proto__:dx.Element.prototype,
		type:ExtensibleShape,
		beginEdit:function(){return this.$.beginEdit();},
		deleteEdge:function(index){return this.$.deleteEdge(index);},
		endEdit:function(){return this.$.endEdit();},
		getCubicSegmentPoints:function(cubicSegmentIndex){
			if(cubicSegmentIndex){
				if(this.cache.cubicSegmentPoints[cubicSegmentIndex]){
					return  this.cache.cubicSegmentPoints[cubicSegmentIndex];
				}
				var csp=this.$.getCubicSegmentPoints(cubicSegmentIndex);
				var points=new dx.Array();
				for(var i=0;i<csp.length;i++){
					points.push(new dx.Point(csp[i]));
				}
				this.cache.cubicSegmentPoints[cubicSegmentIndex]=points;
				return points;
			}else{
				return;
			}
		},
		get contours(){
			if(!this.$){return;}
			if(this.cache['contours']){return this.cache.contours;}
			var contours=new dx.Array();
			for(var i=0;i<this.$.contours.length;i++){
				var c=new dx.Contour(this.$.contours[i],{shape:this});
				var matched=false;
				for(var n=0;n<contours.length;n++){
					if(c.edgeIDs.is(contours[n].edgeIDs)){
						matched=true;
						if(c.interior){
							c.oppositeFill=contours[n].fill;
						}
						contours[n]=c;
						break;
					}
				}
				if(!matched){contours.push(c);}
			}
			this.cache.contours=contours;
			return contours;
		},
		set contours(c){this.cache.contours=c;},
		get edges(){
			if(this.$){
				var edges=new dx.Array();
				var e=this.$.edges;
				for(i=0;i<e;i++){
					edges.push(new dx.Edge(this.$.edges[i]));
				}
				return edges;
			}
		},
		set edges(){return;},
		get isDrawingObject(){if(this.$){return this.$.isDrawingObject;}},
		set isDrawingObject(){return;},
		get isGroup(){if(this.$){return this.$.isGroup;}},set isGroup(){},
		get isOvalObject(){return this.$.isOvalObject;},
		set isOvalObject(){},
		get isRectangleObject(){if(this.$){return this.$.isRectangleObject;}},
		set isRectangleObject(){},
		get members(){
			if(this.$){
				var members = new dx.Selection(this.$.members,this.options);
				for(var i=0;i<members.length;i++){
					members[i].parent=this;	
				}
				return members;
			}
		},
		set members(s){return;},
		get numCubicSegments(){if(this.$){return this.$.numCubicSegments;}},
		set numCubicSegments(){},
		get vertices(){if(this.$){return this.$.vertices;}},
		set vertices(s){return;},
		get objectSpaceBounds(){
			return new dx.Object(this.$.objectSpaceBounds);
		},
		set objectSpaceBounds(s){
			this.$.objectSpaceBounds=s;
		},
		is:function(element,options){
			var settings=new dx.Object({
				checklist:[
					'objectSpaceBounds',
					'numCubicSegments',
					'isGroup',
					'isDrawingObject',
					'contours'
				]		
			});
			settings.extend(options,true);
			return dx.Element.prototype.is.call(this,element,settings);
		}
	}
	dx.extend({Shape:ExtensibleShape});
})(dx);
