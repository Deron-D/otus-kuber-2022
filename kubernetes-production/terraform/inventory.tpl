[all]
%{ for i in range(length(names) - 2) ~}
${names[i]} ansible_host=${ext_addrs[i]} ip=${local_addrs[i]} etcd_member_name=etcd${i+1}
%{ endfor ~}
%{ for i in range(length(names) - 3) ~}
${names[i + 3]} ansible_host=${ext_addrs[i + 3]}
%{ endfor ~}

[kube_control_plane]
%{ for i in range(length(names) - 2) ~}
${names[i]}
%{ endfor ~}

[etcd]
%{ for i in range(length(names) - 2) ~}
${names[i]}
%{ endfor ~}

[kube-node]
%{ for i in range(length(names) - 3) ~}
${names[i + 3]}
%{ endfor ~}

[calico-rr]

[k8s-cluster:children]
kube_control_plane
kube-node
calico-rr