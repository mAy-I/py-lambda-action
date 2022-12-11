#!/bin/bash
set -e

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	if [ "$GITHUB_TOKEN" != "" ] ; then \
    /bin/bash -c "git config --global url.\"https://$(echo $GITHUB_TOKEN)@github.com/\".insteadOf \"https://github.com/\"" ; \
  else \
    echo "    (GITHUB_TOKEN is not privided)"; \
  fi

	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "Publishing dependencies as a layer..."
	local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code itself..."
	zip -r code.zip . -x \*.git\*
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
}

update_function_layers(){
	echo "Using the layer in the function..."
	if [ "$INPUT_LAMBDA_EXTRA_LAYER_ARNS" = "" ] ; then \
		aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers ${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION} ; \
	else \
		aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers ${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION} ${INPUT_LAMBDA_EXTRA_LAYER_ARNS} ; \
	fi
}

deploy_lambda_function(){
	install_zip_dependencies
	publish_dependencies_as_layer
	publish_function_code
	update_function_layers
}

deploy_lambda_function
echo "Done."
