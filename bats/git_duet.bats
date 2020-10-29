#!/usr/bin/env bats

@test "git-duet: push/pull" {
  add_git_duet "clone1"

  git_duet "clone1"
  portal_push "clone1"

  git_duet "clone2"
  portal_pull "clone2"

  portal_push "clone2"
  portal_pull "clone1"
}

@test "validate clean index before pulling" {
  cd clone1
  touch foo.text
  run git status --porcelain=v1
  [ "$output" = "?? foo.text" ]

  run portal pull
  [ "$output" = "git index dirty!" ]
}

@test "validate remote branch exists before pushing" {
  add_git_duet "clone1"

  git_duet "clone1"

  cd clone1
  touch foo.text
  git checkout -b portal-fp-op
  git add .
  git commit -m "WIP"
  git push -u origin portal-fp-op

  run portal push
  [ "$output" = "remote branch portal-fp-op already exists" ]
}

setup() {
  clean_bin
  install_git_duet
  install_portal
  clean_test
  create_remote_repo "project"
  clone "project" "clone1"
  clone "project" "clone2"
}

clean_bin() {
  rm -rf "${BATS_TMPDIR:?BATS_TMPDIR not set}"/bin
}

install_git_duet() {
  git-duet || brew install git-duet
}

install_portal() {
  go build -o "$BATS_TMPDIR"/bin/portal
  PATH=$BATS_TMPDIR/bin:$PATH
}

clean_test() {
  rm -rf "${BATS_TMPDIR:?}"/"${BATS_TEST_NAME:?}"
  mkdir -p "${BATS_TMPDIR:?}"/"${BATS_TEST_NAME:?}"
  cd "${BATS_TMPDIR:?}"/"${BATS_TEST_NAME:?}" || exit
}

create_remote_repo() {
  mkdir "$1" && pushd "$1" && git init --bare && popd || exit
}

clone() {
  git clone "$1" "$2"
  pushd "$2" || exit
  git config user.name test
  git config user.email test@local
  popd || exit
}

add_git_duet() {
  pushd "$1" || exit
  cat > .git-authors <<- EOM
authors:
  fp: Fake Person; fperson
  op: Other Person; operson
email_addresses:
  fp: fperson@email.com
  op: operson@email.com
EOM
  git add .
  git commit -am "Add .git-author"
  git push origin master
  popd || exit

  pushd clone2 || exit
  git pull -r
  popd || exit
}

git_duet() {
  pushd "$1" || exit

  git-duet fp op

  popd || exit
}

portal_push() {
  pushd "$1" || exit

  touch foo.text

  run portal push
  [ "$status" -eq 0 ]

  run git status --porcelain=v1
  [ "$output" = "" ]

  popd || exit
}

portal_pull() {
  pushd "$1" || exit

  run git status --porcelain=v1
  [ "$output" = "" ]

  run portal pull
  echo "$output"
  [ "$status" -eq 0 ]

  run git status --porcelain=v1
  [ "$output" = "?? foo.text" ]

  run git ls-remote --heads origin portal-fp-op
  [ "$output" = "" ]

  popd || exit
}
