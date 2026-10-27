function ,update_repos
    for folder in (ls -d /home/coder/*/)
        echo "FETCHING $folder"
	git -C $folder pull
    end
end
