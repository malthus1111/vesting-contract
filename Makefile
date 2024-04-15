
LIGO = ligo
MAIN_CONTRACT = src/vesting.ligo
OUTPUT_CONTRACT = compiled/vesting.tz
ENTRYPOINT = main

.PHONY: build test deploy clean

# pour compiler mon contrat
build:
	$(LIGO) compile-contract --michelson-format=json $(MAIN_CONTRACT) $(ENTRYPOINT) > $(OUTPUT_CONTRACT)
	@echo "Compilation done."

# Pour exécuter mes tests
test:
	$(LIGO) run test $(MAIN_CONTRACT)
	@echo "Tests executed."

# Pour dé)ployer mon contrat
deploy:
	cd script && npm install && node deploy.ts
	@echo "Deployment script executed."

# Pour nétoyer mon répertoire
clean:
	rm -f $(OUTPUT_CONTRACT)
	@echo "Cleanup done."
