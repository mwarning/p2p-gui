/*
* Some JavaSript enhancements;
* nothing vital for the site to work.
*/

function getParent(start_node, filter_func)
{
	if(filter_func(start_node)) return start_node;
	return getParent(start_node.parentNode, filter_func);
}

function getChildren(start_node, filter_func)
{
	var all = new Array();
	function traverse(node)
	{
		var childs = node.childNodes;
		for(var i = 0; i < childs.length; i++)
		{
			if(filter_func(childs[i])) all.push(childs[i]);
			else traverse(childs[i]);
		}
	}
	traverse(start_node);
	return all;
}

function getAllCheckBoxes(node)
{
	var table = getParent(node, 
		function(node) { return (node.nodeName == "TABLE"); }
	);
	var boxes = getChildren(table,
		function(node) { return (node.checked != undefined); }
	);
	return boxes;
}

function allBoxes(node, value)
{
	var all = getAllCheckBoxes(node);
	for(var i = 0; i < all.length; ++i)
	{
		all[i].checked = value;
	}
}

function invertBoxes(node)
{
	var all = getAllCheckBoxes(node);
	for(var i = 0; i < all.length; ++i)
	{
		all[i].checked = !all[i].checked;
	}
}

function rangeBoxes(node)
{
	var all = getAllCheckBoxes(node);
	var in_range = false;
	
	for(var i = 0; i < all.length; ++i)
	{
		var n = all[i];
		if(n.checked) {
			in_range = !in_range;
		} else if(in_range == true) {
			if(!n.checked) { n.checked = true; }
			else { in_range = true }
		}
	}
}
