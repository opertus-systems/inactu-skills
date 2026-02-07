.PHONY: verify-pins

verify-pins:
	./scripts/verify_pins.sh

bootstrap-base-skills:
	./scripts/bootstrap-base-skills.sh

bootstrap-default-bundle-v0:
	./scripts/bootstrap-default-bundle-v0.sh

rebuild-real-wasm:
	./scripts/rebuild-real-wasm.sh

prepare-release:
	./scripts/prepare-release.sh

release-skill:
	./scripts/release-skill.sh
