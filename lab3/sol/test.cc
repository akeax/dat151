// void printInt(int x) { }
// void printDouble(double x) { }

void
main() {

	int i = 22;
	int ii = foo(i);
	printInt(ii);

}

int foo(int i) {
	return i + 1;
}
