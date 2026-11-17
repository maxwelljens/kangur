extends GdUnitTestSuite
## Infrastructure smoke test: proves the gdUnit4 CLI path in tools/verify.sh works.


func test_framework_is_alive() -> void:
	assert_bool(true).is_true()


func test_math_works() -> void:
	assert_int(2 + 2).is_equal(4)