USER="root"

DEFAULT_HOST="rt"
read -p "Enter Host [default: $DEFAULT_HOST]: " HOST
HOST=${HOST:-$DEFAULT_HOST}

DEFAULT_BRANCH="develop"
read -p "Enter Branch Name [default: $DEFAULT_BRANCH]: " BRANCH
BRANCH=${BRANCH:-$DEFAULT_BRANCH}

cd ~/Documents/repositories/artemis || exit 1

printf "\n=== Fetching Code ===\n"

git pull

git fetch origin "${BRANCH}:${BRANCH}"

git bundle create artemis_update.bundle ${BRANCH}

printf "\n=== Uploading Bundle ===\n"

scp -r artemis_update.bundle ${USER}@${HOST}:/home/artemis

printf "\n=== Logging into ${USER}@${HOST} ===\n"

ssh ${USER}@${HOST} <<EOF

	printf "\n=== Successfully logged into ${USER}@${HOST} ===\n"

	cd /home/artemis

	printf "\n=== Extracting the bundle ===\n"

	git bundle unbundle artemis_update.bundle

	printf "\n=== Deploying Code ===\n"

	printf "\n=== git stash ===\n"
	git stash

	printf "\n=== checkout master ===\n"
	git checkout master

	git branch -D ${BRANCH}

	printf "\n=== git fetch ===\n"
	git fetch artemis_update.bundle 'refs/heads/*:refs/heads/*'

	git checkout -B "${BRANCH}" "${BRANCH}"

	printf "\n=== git merge ===\n"
	git merge FETCH_HEAD

	printf "\n=== Clearing Redis ===\n"

	redis-cli flushall

	printf "\n=== Restarting Repository ===\n"

	pm2 restart artemis

	exit

EOF

printf "\n=== Logged off from ${USER}@${HOST} ===\n"

read -p "Press Enter to exit..."