function syncInputs(lhs, rhs) {
	const first = document.getElementById(lhs);
	const second = document.getElementById(rhs);
	first.value = second.value;
}
