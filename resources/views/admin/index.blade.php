@extends('layouts.admin')

@section('title')
    Dashboard
@endsection

@section('content-header')
    <h1>J&Z Admin <small>Infrastructure control center.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">J&Z Admin</a></li>
        <li class="active">Dashboard</li>
    </ol>
@endsection

@section('content')
<div class="row">
    @foreach([
        ['Users', $stats['users'], 'fa-users', route('admin.users')],
        ['Servers', $stats['servers'], 'fa-server', route('admin.servers')],
        ['Nodes', $stats['nodes'], 'fa-sitemap', route('admin.nodes')],
        ['Online Servers', $stats['onlineServers'], 'fa-heartbeat', route('admin.servers')],
    ] as [$label, $value, $icon, $url])
        <div class="col-lg-3 col-sm-6">
            <a href="{{ $url }}" class="jz-stat-card">
                <span class="jz-stat-icon"><i class="fa {{ $icon }}"></i></span>
                <span><small>{{ $label }}</small><strong>{{ number_format($value) }}</strong></span>
            </a>
        </div>
    @endforeach
</div>
<div class="row">
    <div class="col-md-8">
        <div class="box">
            <div class="box-header with-border"><h3 class="box-title">System status</h3></div>
            <div class="box-body">
                <div class="jz-status-grid">
                    <div><span class="jz-dot jz-dot-success"></span><strong>Panel</strong><small>Application online</small></div>
                    <div><span class="jz-dot jz-dot-success"></span><strong>Database</strong><small>Connected through Laravel</small></div>
                    <div><span class="jz-dot jz-dot-success"></span><strong>Queue</strong><small>Managed by configured workers</small></div>
                    <div><span class="jz-dot jz-dot-success"></span><strong>Wings</strong><small>Health is reported per node</small></div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="box">
            <div class="box-header with-border"><h3 class="box-title">Release</h3></div>
            <div class="box-body">
                <p style="color:var(--jz-muted)">J&Z Panel application version</p>
                <h2 style="margin:8px 0">{{ config('app.version') }}</h2>
                @if ($version->isLatestPanel())
                    <span class="label label-success">Up to date</span>
                @else
                    <span class="label label-warning">Update available</span>
                @endif
            </div>
        </div>
    </div>
</div>
<div class="row">
    <div class="col-xs-12">
        <div class="box">
            <div class="box-header with-border"><h3 class="box-title">Quick administration</h3></div>
            <div class="box-body jz-quick-links">
                <a href="{{ route('admin.users') }}"><i class="fa fa-users"></i><span>Manage users</span></a>
                <a href="{{ route('admin.servers') }}"><i class="fa fa-server"></i><span>Manage servers</span></a>
                <a href="{{ route('admin.nodes') }}"><i class="fa fa-sitemap"></i><span>Manage nodes</span></a>
                <a href="{{ route('admin.nests') }}"><i class="fa fa-th-large"></i><span>Manage eggs</span></a>
                <a href="{{ route('admin.settings') }}"><i class="fa fa-wrench"></i><span>Panel settings</span></a>
            </div>
        </div>
    </div>
</div>
@endsection
