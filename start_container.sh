#!/bin/bash

print_help() {
	echo "usage: $0 compiler src_dir out_dir [-n] [-e VAR] [-h] [-v] [-p] [-- cmd with args]"
	echo "  -n    launch container in non-interactive mode"
	echo "  -e    add environment variable in the container (may be used multiple times)"
	echo "  -h    print this help"
	echo "  -v    enable debug output"
	echo "  -p    use podman runtime instead of docker"
	echo ""
	echo "  If cmd is empty, we will start an interactive bash in the container."
}

if [ $# -lt 3 ]; then
	print_help
	exit 1
fi

COMPILER=$1
SRC="$2"
OUT="$3"
shift 3

# defaults
CIDFILE=""
ENV=""
INTERACTIVE="-it"
IMAGE_ENGINE="docker"

while [[ $# -gt 0 ]]; do
	case $1 in
	-n | --non-interactive)
		INTERACTIVE=""
		CIDFILE="--cidfile $OUT/container.id"
		echo "Run image engine in NON-interactive mode"
		shift
		;;
	-e | --env)
		# `set -eu` will prevent out-of-bounds access
		ENV="$ENV -e $2"
		shift 2
		;;
	-v | --verbose)
		set -x
		shift
		;;
	-p | --podman)
		IMAGE_ENGINE="podman"
		shift
		;;
	-h | --help)
		print_help
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		echo "Unknown option $1"
		print_help
		exit 1
		;;
	esac
done

output=$($IMAGE_ENGINE ps 2>&1)

set -eu 
if echo "$output" | grep -qi "permission denied" && [ "$IMAGE_ENGINE" = "docker" ]; then
	echo "Hey, we gonna use sudo for running docker"
	SUDO_CMD="sudo"
elif [ "$IMAGE_ENGINE" = "podman" ]; then
    echo "Hey, you are running podman, sudo is not needed"
    SUDO_CMD=""
else
    echo "Hey, you are in docker group, sudo is not needed"
    SUDO_CMD=""
fi

echo "Starting \"kernel-build-container:$COMPILER\""

if [ ! -z "$ENV" ]; then
	echo "Container environment arguments: $ENV"
fi

if [ ! -z $INTERACTIVE ]; then
	echo "Gonna run $IMAGE_ENGINE in interactive mode"
fi

echo "Mount source code directory \"$SRC\" at \"/src\""
echo "Mount build output directory \"$OUT\" at \"/out\""

if [ $# -gt 0 ]; then
	echo -e "Gonna run command \"$@\"\n"
else
	echo -e "Gonna run bash\n"
fi

# Z for setting SELinux label
exec $SUDO_CMD $IMAGE_ENGINE run $ENV $INTERACTIVE $CIDFILE --rm \
	-v $SRC:/src:Z \
	-v $OUT:/out:Z \
	kernel-build-container:$COMPILER "$@"
